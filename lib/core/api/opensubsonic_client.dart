import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../lyrics/lyrics.dart';
import '../lyrics/structured_lyrics.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import '../models/json_util.dart';
import '../models/playlist.dart';
import '../models/radio_station.dart';
import '../models/search_results.dart';
import '../models/server_play_queue.dart';
import '../models/track.dart';
import 'api_exception.dart';
import 'library_api.dart';
import 'server_config.dart';

/// OpenSubsonic REST client on `dio`. No SDK: just the endpoints Tidewater
/// uses. Auth is `md5(password + salt)` or an API key (`apiKey` param).
class OpenSubsonicClient implements LibraryApi {
  OpenSubsonicClient(this.config, {Dio? dio, math.Random? random})
      : _random = random ?? math.Random.secure(),
        _dio = dio ?? _createDio(config);

  static const apiVersion = '1.16.1';
  static const clientName = 'Tidewater';

  final ServerConfig config;
  final Dio _dio;
  final math.Random _random;

  static Dio _createDio(ServerConfig config) {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      // We map every status ourselves.
      validateStatus: (_) => true,
    ));
    if (config.trustBadCertificate) {
      final host = config.baseUrl.host;
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient()..badCertificateCallback = (cert, h, port) => h == host,
      );
    }
    return dio;
  }

  // --- URLs and auth -------------------------------------------------------

  /// Auth plus the fixed Subsonic params, with a fresh salt.
  Map<String, String> authParams() {
    final base = {'v': apiVersion, 'c': clientName, 'f': 'json'};
    return switch (config.credentials) {
      ApiKeyCredentials(:final apiKey) => {...base, 'apiKey': apiKey},
      PasswordCredentials(:final username, :final password) => () {
          final salt = _newSalt();
          final token = md5.convert(utf8.encode('$password$salt')).toString();
          return {...base, 'u': username, 't': token, 's': salt};
        }(),
    };
  }

  String _newSalt() => [for (var i = 0; i < 8; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();

  Uri _uri(String endpoint, [Map<String, Object?> params = const {}]) {
    final base = config.baseUrl;
    return base.replace(
      path: '${base.path}/rest/$endpoint',
      queryParameters: {
        ...authParams(),
        for (final e in params.entries)
          if (e.value != null)
            e.key: e.value is Iterable ? [for (final v in e.value as Iterable) v.toString()] : e.value.toString(),
      },
    );
  }

  @override
  Uri coverArtUri(String id, {int size = 300}) => _uri('getCoverArt', {'id': id, 'size': size});

  @override
  Uri streamUri(String trackId) => _uri('stream', {'id': trackId});

  // --- Transport -----------------------------------------------------------

  Future<Response<T>> _send<T>(Uri uri, ResponseType type) async {
    try {
      return await _dio.getUri<T>(uri, options: Options(responseType: type));
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  ApiException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.badCertificate:
        return const ApiException(
          ApiErrorKind.tls,
          'The server\'s security certificate isn\'t trusted. If this is your own server, you can choose to trust it.',
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(ApiErrorKind.unreachable, 'The server took too long to answer.');
      case DioExceptionType.connectionError:
        final inner = e.error;
        if (inner is HandshakeException || inner is TlsException) {
          return const ApiException(
            ApiErrorKind.tls,
            'The server\'s security certificate isn\'t trusted. If this is your own server, you can choose to trust it.',
          );
        }
        return const ApiException(ApiErrorKind.unreachable, 'Couldn\'t reach the server. Check the address and your connection.');
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.unreachable, 'The request was cancelled.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        final inner = e.error;
        if (inner is HandshakeException || inner is TlsException) {
          return const ApiException(ApiErrorKind.tls, 'The server\'s security certificate isn\'t trusted.');
        }
        if (inner is SocketException) {
          return const ApiException(ApiErrorKind.unreachable, 'Couldn\'t reach the server. Check the address and your connection.');
        }
        return ApiException(ApiErrorKind.unreachable, 'Couldn\'t talk to the server (${e.message ?? 'unknown error'}).');
    }
  }

  /// Calls a JSON endpoint and returns the `subsonic-response` body.
  Future<Map<String, dynamic>> _call(String endpoint, [Map<String, Object?> params = const {}]) async =>
      _answer(await _send<String>(_uri(endpoint, params), ResponseType.plain));

  /// Same, but the parameters travel in a form-encoded POST body (the login stays
  /// in the address). For calls whose parameters would not fit in a URL, such as
  /// a queue of thousands of song ids.
  Future<Map<String, dynamic>> _post(String endpoint, Map<String, Object?> params) async {
    final body = Uri(
      queryParameters: {
        for (final e in params.entries)
          if (e.value != null) e.key: e.value is Iterable ? [for (final v in e.value as Iterable) v.toString()] : e.value.toString(),
      },
    ).query;
    try {
      final res = await _dio.postUri<String>(
        _uri(endpoint),
        data: body,
        options: Options(contentType: Headers.formUrlEncodedContentType, responseType: ResponseType.plain),
      );
      return await _answer(res);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> _answer(Response<String> res) async {
    final status = res.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw const ApiException(ApiErrorKind.badCredentials, 'The server refused the login.');
    }
    if (status >= 500) {
      throw ApiException(ApiErrorKind.server, 'The server had a problem (HTTP $status).');
    }
    final text = res.data;
    // A big answer (a page of 500 songs is about half a megabyte) is decoded on another thread,
    // so a library load does not hold up the frames on this one.
    final body = text != null && text.length > _offThreadBytes
        ? await Isolate.run(() => _decode(text))
        : _decode(text);
    if (body == null) {
      throw ApiException(
        ApiErrorKind.notSubsonic,
        status == 404
            ? 'Nothing answered at that address. Check the URL (and any sub-path).'
            : 'That address answered, but it doesn\'t look like a Navidrome server.',
      );
    }
    if (body['status'] != 'ok') {
      final err = body['error'];
      final code = err is Map ? asInt(err['code']) : null;
      final message = (err is Map ? asString(err['message']) : null) ?? 'The server reported an error.';
      throw ApiException(_kindForCode(code), _friendly(code, message), code: code);
    }
    return body;
  }

  static const _offThreadBytes = 64 * 1024;

  static Map<String, dynamic>? _decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic> && json['subsonic-response'] is Map<String, dynamic>) {
        return json['subsonic-response'] as Map<String, dynamic>;
      }
    } on FormatException {
      // Not JSON (an HTML page, a proxy error): handled by the caller.
    }
    return null;
  }

  static ApiErrorKind _kindForCode(int? code) => switch (code) {
        40 || 41 || 44 => ApiErrorKind.badCredentials,
        42 || 43 => ApiErrorKind.unsupported,
        50 => ApiErrorKind.badCredentials,
        70 => ApiErrorKind.notFound,
        _ => ApiErrorKind.server,
      };

  static String _friendly(int? code, String message) => switch (code) {
        40 => 'Wrong username or password.',
        41 => 'This server can\'t use token login. Try an API key instead.',
        44 => 'That API key isn\'t valid.',
        50 => 'That account isn\'t allowed to do this.',
        70 => 'That item no longer exists on the server.',
        _ => message,
      };

  // --- Endpoints -----------------------------------------------------------

  @override
  Future<ServerInfo> ping() async {
    final body = await _call('ping');
    var info = ServerInfo(
      apiVersion: asString(body['version']) ?? apiVersion,
      serverName: asString(body['type']),
      serverVersion: asString(body['serverVersion']),
      openSubsonic: body['openSubsonic'] == true,
    );
    if (info.openSubsonic) {
      try {
        final ext = await _call('getOpenSubsonicExtensions');
        info = info.withExtensions({
          for (final e in asObjects(ext['openSubsonicExtensions'])) ?asString(e['name']),
        });
      } on ApiException {
        // Optional: a server without the endpoint just has no extensions.
      }
    }
    return info;
  }

  @override
  Future<List<Album>> getAlbumList(
    AlbumListType type, {
    int size = 20,
    int offset = 0,
    int? fromYear,
    int? toYear,
    String? genre,
  }) async {
    final body = await _call('getAlbumList2', {
      'type': type.wire,
      'size': size,
      'offset': offset,
      if (type == AlbumListType.byYear) ...{'fromYear': fromYear ?? 0, 'toYear': toYear ?? 9999},
      if (type == AlbumListType.byGenre) 'genre': genre ?? '',
    });
    final list = body['albumList2'];
    return [for (final a in asObjects(list is Map ? list['album'] : null)) Album.fromJson(a)];
  }

  @override
  Future<List<RadioStation>> getRadioStations() async {
    final body = await _call('getInternetRadioStations');
    final list = body['internetRadioStations'];
    return [for (final s in asObjects(list is Map ? list['internetRadioStation'] : null)) RadioStation.fromJson(s)];
  }

  @override
  Future<void> createRadioStation({required String name, required String streamUrl, String? homepageUrl}) async {
    await _call('createInternetRadioStation', {'name': name, 'streamUrl': streamUrl, 'homepageUrl': homepageUrl});
  }

  @override
  Future<void> updateRadioStation(String id, {required String name, required String streamUrl, String? homepageUrl}) async {
    await _call('updateInternetRadioStation', {'id': id, 'name': name, 'streamUrl': streamUrl, 'homepageUrl': homepageUrl});
  }

  @override
  Future<void> deleteRadioStation(String id) async {
    await _call('deleteInternetRadioStation', {'id': id});
  }

  @override
  Future<List<Genre>> getGenres() async {
    final body = await _call('getGenres');
    final list = body['genres'];
    return [for (final g in asObjects(list is Map ? list['genre'] : null)) Genre.fromJson(g)];
  }

  @override
  Future<List<Track>> getSongsByGenre(String genre, {int size = 500, int offset = 0}) async {
    final body = await _call('getSongsByGenre', {'genre': genre, 'count': size, 'offset': offset});
    final list = body['songsByGenre'];
    return [for (final s in asObjects(list is Map ? list['song'] : null)) Track.fromJson(s)];
  }

  @override
  Future<AlbumDetail> getAlbum(String id) async {
    final body = await _call('getAlbum', {'id': id});
    return AlbumDetail.fromJson(_object(body, 'album'));
  }

  @override
  Future<List<Artist>> getArtists() async {
    final body = await _call('getArtists');
    final artists = body['artists'];
    if (artists is! Map) return const [];
    return [
      for (final bucket in asObjects(artists['index']))
        for (final a in asObjects(bucket['artist'])) Artist.fromJson(a),
    ];
  }

  @override
  Future<ArtistDetail> getArtist(String id) async {
    final body = await _call('getArtist', {'id': id});
    return ArtistDetail.fromJson(_object(body, 'artist'));
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    final body = await _call('getPlaylists');
    final list = body['playlists'];
    return [for (final p in asObjects(list is Map ? list['playlist'] : null)) Playlist.fromJson(p)];
  }

  @override
  Future<Playlist?> createPlaylist({String? name, String? playlistId, List<String> songIds = const []}) async {
    final params = {'name': name, 'playlistId': playlistId, 'songId': songIds};
    final body = songIds.length > _maxIdsInUrl ? await _post('createPlaylist', params) : await _call('createPlaylist', params);
    final p = body['playlist'];
    return p is Map<String, dynamic> ? Playlist.fromJson(p) : null;
  }

  @override
  Future<void> updatePlaylist(
    String playlistId, {
    String? name,
    bool? isPublic,
    List<String> addSongIds = const [],
    List<int> removeIndexes = const [],
  }) async {
    final params = {
      'playlistId': playlistId,
      'name': name,
      'public': isPublic,
      'songIdToAdd': addSongIds.isEmpty ? null : addSongIds,
      'songIndexToRemove': removeIndexes.isEmpty ? null : removeIndexes,
    };
    if (addSongIds.length + removeIndexes.length > _maxIdsInUrl) {
      await _post('updatePlaylist', params);
    } else {
      await _call('updatePlaylist', params);
    }
  }

  @override
  Future<void> deletePlaylist(String playlistId) => _call('deletePlaylist', {'id': playlistId});

  @override
  Future<PlaylistDetail> getPlaylist(String id) async {
    final body = await _call('getPlaylist', {'id': id});
    return PlaylistDetail.fromJson(_object(body, 'playlist'));
  }

  @override
  Future<SearchResults> search(String query, {int artistCount = 5, int albumCount = 10, int songCount = 20}) async {
    final body = await _call('search3', {
      'query': query,
      'artistCount': artistCount,
      'albumCount': albumCount,
      'songCount': songCount,
    });
    final result = body['searchResult3'];
    return result is Map<String, dynamic> ? SearchResults.fromJson(result) : const SearchResults();
  }

  @override
  Future<List<Track>> getSongs({int offset = 0, int size = 500}) async {
    final body = await _call('search3', {
      'query': '',
      'artistCount': 0,
      'albumCount': 0,
      'songCount': size,
      'songOffset': offset,
    });
    final result = body['searchResult3'];
    return [for (final s in asObjects(result is Map ? result['song'] : null)) Track.fromJson(s)];
  }

  @override
  Future<List<Track>> getRandomSongs({int size = 30}) async {
    final body = await _call('getRandomSongs', {'size': size});
    final list = body['randomSongs'];
    return [for (final s in asObjects(list is Map ? list['song'] : null)) Track.fromJson(s)];
  }

  @override
  Future<List<Track>> getStarredSongs() async {
    final body = await _call('getStarred2', const {});
    final starred = body['starred2'];
    return [for (final s in asObjects(starred is Map ? starred['song'] : null)) Track.fromJson(s)];
  }

  @override
  Future<Lyrics?> getLyrics(String trackId) async {
    try {
      final body = await _call('getLyricsBySongId', {'id': trackId});
      return parseStructuredLyrics(body['lyricsList']);
    } on ApiException catch (e) {
      // "No lyrics", or a server that has never heard of the call.
      if (e.kind == ApiErrorKind.notFound || e.kind == ApiErrorKind.unsupported || e.kind == ApiErrorKind.notSubsonic) return null;
      rethrow;
    }
  }

  @override
  Future<Uint8List> getCoverArt(String id, {int size = 300}) async {
    final res = await _send<List<int>>(_uri('getCoverArt', {'id': id, 'size': size}), ResponseType.bytes);
    final type = res.headers.value(Headers.contentTypeHeader) ?? '';
    final data = res.data;
    if (res.statusCode != 200 || data == null || data.isEmpty || !type.startsWith('image/')) {
      throw ApiException(
        res.statusCode == 404 ? ApiErrorKind.notFound : ApiErrorKind.server,
        'No cover art for $id.',
      );
    }
    return Uint8List.fromList(data);
  }

  @override
  Future<void> star({String? trackId, String? albumId, String? artistId}) =>
      _call('star', {'id': trackId, 'albumId': albumId, 'artistId': artistId});

  @override
  Future<void> unstar({String? trackId, String? albumId, String? artistId}) =>
      _call('unstar', {'id': trackId, 'albumId': albumId, 'artistId': artistId});

  @override
  Future<void> scrobble(String trackId, {bool submission = false, DateTime? time}) =>
      _call('scrobble', {
        'id': trackId,
        'submission': submission,
        'time': (time ?? DateTime.now()).millisecondsSinceEpoch,
      });

  @override
  Future<ScanStatus> startScan() async => _scanStatus(await _call('startScan'));

  @override
  Future<ScanStatus> getScanStatus() async => _scanStatus(await _call('getScanStatus'));

  static ScanStatus _scanStatus(Map<String, dynamic> body) {
    final s = body['scanStatus'];
    if (s is! Map<String, dynamic>) return const ScanStatus(scanning: false);
    return ScanStatus(scanning: s['scanning'] == true, count: asInt(s['count']) ?? 0);
  }

  @override
  Future<void> savePlayQueue(List<String> ids, {String? current, Duration position = Duration.zero}) {
    final params = {'id': ids, 'current': current, 'position': position.inMilliseconds};
    // A hundred ids fit in an address; thousands (a queue of the whole library) go in the body.
    return ids.length > _maxIdsInUrl ? _post('savePlayQueue', params) : _call('savePlayQueue', params);
  }

  static const _maxIdsInUrl = 100;

  @override
  Future<ServerPlayQueue?> getPlayQueue() async {
    final body = await _call('getPlayQueue');
    final q = body['playQueue'];
    if (q is! Map<String, dynamic>) return null;
    final queue = ServerPlayQueue.fromJson(q);
    return queue.isEmpty ? null : queue;
  }

  @override
  void close() => _dio.close();

  Map<String, dynamic> _object(Map<String, dynamic> body, String key) {
    final v = body[key];
    if (v is Map<String, dynamic>) return v;
    throw ApiException(ApiErrorKind.notSubsonic, 'The server\'s answer was missing "$key".');
  }
}
