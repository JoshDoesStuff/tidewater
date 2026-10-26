import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/opensubsonic_client.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'dart:convert';

import '../support/stub_adapter.dart';

final _base = Uri.parse('https://music.example.com');

OpenSubsonicClient _client(
  StubAdapter adapter, {
  Credentials credentials = const PasswordCredentials('josh', 'sesame'),
  Uri? base,
}) =>
    OpenSubsonicClient(
      ServerConfig(baseUrl: base ?? _base, credentials: credentials),
      dio: stubDio(adapter),
      random: Random(1),
    );

StubAdapter _routes(Map<String, String> byEndpoint, {int status = 200}) => StubAdapter((uri) {
      final endpoint = uri.pathSegments.last;
      final fixture = byEndpoint[endpoint];
      if (fixture == null) return StubResponse('not found', status: 404, contentType: 'text/plain');
      return StubResponse.fixture(fixture, status: status);
    });

void main() {
  group('auth', () {
    test('token auth sends md5(password + salt), never the password', () async {
      final adapter = _routes({'ping': 'ping_ok.json'});
      await _client(adapter).ping();
      final q = adapter.requests.first.queryParameters;
      expect(q['u'], 'josh');
      expect(q['v'], '1.16.1');
      expect(q['c'], 'Tidewater');
      expect(q['f'], 'json');
      expect(q['t'], md5.convert(utf8.encode('sesame${q['s']}')).toString());
      expect(adapter.requests.first.toString(), isNot(contains('sesame')));
      expect(q.containsKey('apiKey'), isFalse);
    });

    test('every request uses a fresh salt', () async {
      final adapter = _routes({'ping': 'ping_ok.json'});
      final c = _client(adapter);
      await c.ping();
      await c.ping();
      expect(adapter.requests[0].queryParameters['s'], isNot(adapter.requests[2].queryParameters['s']));
    });

    test('api key auth sends apiKey and no user, token or salt', () async {
      final adapter = _routes({'ping': 'ping_ok.json'});
      await _client(adapter, credentials: const ApiKeyCredentials('k-123', username: 'josh')).ping();
      final q = adapter.requests.first.queryParameters;
      expect(q['apiKey'], 'k-123');
      expect(q.keys, isNot(containsAll(['u'])));
      expect(q.containsKey('t'), isFalse);
      expect(q.containsKey('s'), isFalse);
    });

    test('stream url carries auth and keeps a reverse-proxy sub-path', () {
      final c = _client(StubAdapter((_) => StubResponse('')), base: Uri.parse('https://example.com/navidrome'));
      final uri = c.streamUri('tr-1');
      expect(uri.path, '/navidrome/rest/stream');
      expect(uri.queryParameters['id'], 'tr-1');
      expect(uri.queryParameters['t'], isNotEmpty);
    });
  });

  group('ping', () {
    test('reads server info and OpenSubsonic extensions', () async {
      final info = await _client(_routes({'ping': 'ping_ok.json', 'getOpenSubsonicExtensions': 'extensions.json'})).ping();
      expect(info.serverName, 'navidrome');
      expect(info.openSubsonic, isTrue);
      expect(info.supports('apiKeyAuthentication'), isTrue);
      expect(info.supports('songLyrics'), isTrue);
      expect(info.supports('formPost'), isFalse);
    });

    test('a missing extensions endpoint is not fatal', () async {
      final info = await _client(_routes({'ping': 'ping_ok.json'})).ping();
      expect(info.extensions, isEmpty);
    });
  });

  group('errors', () {
    Future<ApiException> failure(StubAdapter adapter) async {
      try {
        await _client(adapter).ping();
      } on ApiException catch (e) {
        return e;
      }
      fail('expected an ApiException');
    }

    test('error 40 means bad credentials', () async {
      final e = await failure(_routes({'ping': 'error_40.json'}));
      expect(e.kind, ApiErrorKind.badCredentials);
      expect(e.code, 40);
      expect(e.message, contains('username or password'));
    });

    test('HTML answer is not a Subsonic server', () async {
      final e = await failure(StubAdapter((_) => StubResponse('<html>hi</html>', contentType: 'text/html')));
      expect(e.kind, ApiErrorKind.notSubsonic);
    });

    test('404 points at the URL', () async {
      final e = await failure(StubAdapter((_) => StubResponse('nope', status: 404, contentType: 'text/plain')));
      expect(e.kind, ApiErrorKind.notSubsonic);
      expect(e.message, contains('URL'));
    });

    test('401 from a proxy is bad credentials, 502 is a server problem', () async {
      expect((await failure(StubAdapter((_) => StubResponse('', status: 401)))).kind, ApiErrorKind.badCredentials);
      expect((await failure(StubAdapter((_) => StubResponse('', status: 502)))).kind, ApiErrorKind.server);
    });

    test('transport failures map to unreachable and tls', () async {
      DioException dioError(DioExceptionType t) => DioException(requestOptions: RequestOptions(), type: t);
      expect((await failure(StubAdapter((_) => throw dioError(DioExceptionType.connectionTimeout)))).kind, ApiErrorKind.unreachable);
      expect((await failure(StubAdapter((_) => throw dioError(DioExceptionType.connectionError)))).kind, ApiErrorKind.unreachable);
      expect((await failure(StubAdapter((_) => throw dioError(DioExceptionType.badCertificate)))).kind, ApiErrorKind.tls);
    });
  });

  group('library', () {
    late OpenSubsonicClient client;
    late StubAdapter adapter;

    setUp(() {
      adapter = _routes({
        'getAlbumList2': 'album_list.json',
        'getAlbum': 'album.json',
        'getArtists': 'artists.json',
        'getArtist': 'artist.json',
        'getPlaylists': 'playlists.json',
        'getPlaylist': 'playlist.json',
        'search3': 'search3.json',
      });
      client = _client(adapter);
    });

    test('getAlbumList parses albums and sends type, size and offset', () async {
      final albums = await client.getAlbumList(AlbumListType.newest, size: 2, offset: 4);
      final q = adapter.requests.first.queryParameters;
      expect(q['type'], 'newest');
      expect(q['size'], '2');
      expect(q['offset'], '4');
      expect(albums.map((a) => a.id), ['al-1', 'al-2']);
      final a = albums.first;
      expect(a.title, 'Glass Orchard');
      expect(a.artistId, 'ar-1');
      expect(a.coverArt, 'al-1_6600');
      expect(a.year, 2021);
      expect(a.duration, const Duration(seconds: 2412));
      expect(a.starred, isTrue);
      expect(a.created, DateTime.utc(2024, 3, 2, 10, 11, 12));
      expect(albums.last.coverArt, isNull);
      expect(albums.last.starred, isFalse);
    });

    test('getAlbum parses tracks, inherits album fields and tolerates strings for numbers', () async {
      final d = await client.getAlbum('al-1');
      expect(d.tracks.length, 2);
      final t = d.tracks.first;
      expect(t.coverArt, 'mf-tr-1_6600');
      expect(t.qualityLabel, 'FLAC · 24-bit / 96 kHz');
      final second = d.tracks.last;
      expect(second.artist, 'Mira Vale'); // from the album
      expect(second.albumId, 'al-1');
      expect(second.coverArt, 'al-1_6600');
      expect(second.duration, const Duration(seconds: 200));
      expect(second.trackNumber, 2);
      expect(second.qualityLabel, 'MP3 · 320 kbps');
    });

    test('getArtists flattens the index buckets', () async {
      final artists = await client.getArtists();
      expect(artists.map((a) => a.name), ['Koji & the Static', 'Mira Vale']);
    });

    test('getArtist accepts a single album given as an object', () async {
      final d = await client.getArtist('ar-1');
      expect(d.albums.single.id, 'al-1');
    });

    test('playlists and search', () async {
      expect((await client.getPlaylists()).single.name, 'Late night');
      final p = await client.getPlaylist('pl-1');
      expect(p.tracks.single.title, 'Lantern Season');
      final r = await client.search('mira');
      expect(adapter.requests.last.queryParameters['query'], 'mira');
      expect(r.artists.single.name, 'Mira Vale');
      expect(r.albums.single.id, 'al-1');
      expect(r.tracks.single.id, 'tr-1');
    });

    test('getCoverArt requests the size and returns image bytes', () async {
      final bytes = [137, 80, 78, 71];
      final c = _client(StubAdapter((_) => StubResponse(bytes, contentType: 'image/png')));
      expect(await c.getCoverArt('al-1_6600', size: 800), bytes);
    });

    test('getCoverArt fails when the server answers with JSON (no art)', () async {
      final c = _client(StubAdapter((_) => StubResponse.fixture('error_40.json')));
      expect(c.getCoverArt('x'), throwsA(isA<ApiException>()));
    });

    test('scrobble sends submission flag', () async {
      final a = _routes({'scrobble': 'ping_ok.json'});
      await _client(a).scrobble('tr-1', submission: true);
      expect(a.requests.first.queryParameters['submission'], 'true');
      expect(a.requests.first.queryParameters['id'], 'tr-1');
    });

    test('a short play queue goes in the address, a huge one in a POST body', () async {
      final a = _routes({'savePlayQueue': 'ping_ok.json'});
      final c = _client(a);
      await c.savePlayQueue(['a', 'b'], current: 'b', position: const Duration(seconds: 12));
      expect(a.methods.last, 'GET');
      expect(a.requests.last.queryParametersAll['id'], ['a', 'b']);
      expect(a.requests.last.queryParameters['position'], '12000');

      final ids = [for (var i = 0; i < 5000; i++) 'song-$i'];
      await c.savePlayQueue(ids, current: 'song-42', position: const Duration(seconds: 3));
      expect(a.methods.last, 'POST');
      expect(a.requests.last.toString().length, lessThan(400), reason: 'the address stays short');
      expect(a.requests.last.queryParameters['u'], 'josh', reason: 'the login stays in the address');
      final body = a.bodies.last;
      expect(body.split('&').where((p) => p.startsWith('id=')).length, 5000);
      expect(body, contains('current=song-42'));
      expect(body, contains('position=3000'));
      expect(body, isNot(contains('sesame')));
    });
  });

  group('parseServerUrl', () {
    test('no scheme tries https then http', () {
      expect(parseServerUrl('music.example.com').map((u) => u.toString()), ['https://music.example.com', 'http://music.example.com']);
    });

    test('keeps port and sub-path, drops trailing slash, /rest and /app', () {
      expect(parseServerUrl('http://192.168.1.5:4533/').single.toString(), 'http://192.168.1.5:4533');
      expect(parseServerUrl('https://example.com/navidrome/rest/').single.toString(), 'https://example.com/navidrome');
      expect(parseServerUrl('https://example.com/app').single.toString(), 'https://example.com');
    });

    test('empty and nonsense are bad URLs', () {
      expect(() => parseServerUrl('  '), throwsA(isA<ApiException>()));
      expect(() => parseServerUrl('ftp://x.y'), throwsA(isA<ApiException>()));
    });
  });
}
