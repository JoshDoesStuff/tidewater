import 'dart:async';
import 'dart:typed_data';

import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/lyrics/lyrics.dart';
import 'package:tidewater/core/models/album.dart';
import 'package:tidewater/core/models/artist.dart';
import 'package:tidewater/core/models/playlist.dart';
import 'package:tidewater/core/models/search_results.dart';
import 'package:tidewater/core/models/server_play_queue.dart';
import 'package:tidewater/core/models/track.dart';

import 'placeholder_lyrics.dart';

/// (id, title, artist, track title, genre, year)
const _seed = [
  ('a0', 'Glass Orchard', 'Mira Vale', 'Lantern Season', 'Indie', 2021),
  ('a1', 'Night Transit', 'Koji & the Static', 'Last Tram Home', 'Electronic', 2019),
  ('a2', 'Low Tide Letters', 'Ana Soleil', 'Salt on the Window', 'Folk', 2022),
  ('a3', 'Paper Satellites', 'Hollow Pines', 'Orbit of Small Things', 'Indie', 2018),
  ('a4', 'Velvet Static', 'Dune Parade', 'Velvet Static', 'Electronic', 2023),
  ('a5', 'Saltwater Hymns', 'Orla Finch', 'Harbour Lights', 'Folk', 2020),
  ('a6', 'Neon Cartography', 'Quiet Engine', 'Map of Neon', 'Electronic', 2017),
  ('a7', 'Slow Meridian', 'Tove Lind', 'Slow Meridian', 'Indie', 2021),
  ('a8', 'Ember Hours', 'The Lanterns', 'Embers, Late', 'Folk', 2016),
  ('a9', 'Fieldwork', 'Marin Cho', 'Field Recording 4', 'Indie', 2024),
  ('a10', 'Afterglow Theory', 'Juno Park', 'Afterglow', 'Electronic', 2015),
  ('a11', 'Cobalt Rooms', 'Eli Marsh', 'Room 9', 'Indie', 2022),
];

final fakeAlbums = <Album>[
  for (final (id, title, artist, _, genre, year) in _seed)
    Album(
      id: id,
      title: title,
      artist: artist,
      artistId: 'ar-$id',
      coverArt: 'cv-$id',
      genre: genre,
      year: year,
      songCount: id == 'a1' ? 3 : 1,
      duration: Duration(seconds: id == 'a1' ? 600 : 200),
    ),
];

/// Album `a1` has three tracks (to test skipping inside one album); the others
/// have one, 3:20 long.
final fakeTracks = <Track>[
  for (final (i, a) in fakeAlbums.indexed)
    for (var n = 0; n < (a.id == 'a1' ? 3 : 1); n++)
      Track(
        id: 't-${a.id}${n == 0 ? '' : '-$n'}',
        title: n == 0 ? _seed[i].$4 : '${_seed[i].$4} ${n + 1}',
        artist: a.artist,
        albumId: a.id,
        albumTitle: a.title,
        coverArt: a.coverArt,
        duration: const Duration(seconds: 200),
        trackNumber: n + 1,
        suffix: 'flac',
        starred: a.id == 'a2',
        samplingRate: 96000,
        bitDepth: 24,
      ),
];

final fakeArtists = <Artist>[
  for (final a in fakeAlbums) Artist(id: a.artistId!, name: a.artist, albumCount: 1),
];

final fakePlaylists = <Playlist>[
  const Playlist(id: 'pl-1', name: 'Late Night Drive', songCount: 2, owner: 'josh'),
  const Playlist(id: 'pl-2', name: 'Focus', songCount: 1, owner: 'josh'),
];

/// An in-memory server. Cover art always fails, so tests see the placeholder
/// gradients (and a scheme seeded from the album id).
class FakeLibraryApi implements LibraryApi {
  FakeLibraryApi({this.failWith, this.albums});

  /// Track ids the server has no lyrics for (every other track gets the placeholder).
  final noLyricsFor = <String>{};

  /// When set, `star` and `unstar` throw this.
  ApiException? failStarWith;

  /// When set, `scrobble` throws this (the rest keeps working).
  ApiException? failScrobbleWith;

  /// When set, every list/detail call throws this.
  ApiException? failWith;

  /// Replaces the default songs (for big-library tests).
  List<Track>? songs;

  /// Replaces the default albums (for big-library and empty tests).
  List<Album>? albums;

  /// Holds a track's lyrics lookup open until the completer is completed.
  final lyricsGate = <String, Completer<void>>{};

  /// Holds an album list request open until the completer is completed.
  final listGate = <AlbumListType, Completer<void>>{};

  final calls = <String>[];

  List<Album> get _albums => albums ?? fakeAlbums;

  T _ok<T>(String call, T Function() value) {
    calls.add(call);
    final e = failWith;
    if (e != null) throw e;
    return value();
  }

  @override
  Future<ServerInfo> ping() async => _ok(
        'ping',
        () => const ServerInfo(
          apiVersion: '1.16.1',
          serverName: 'navidrome',
          openSubsonic: true,
          extensions: {'apiKeyAuthentication', 'songLyrics'},
        ),
      );

  @override
  Future<List<Album>> getAlbumList(AlbumListType type, {int size = 20, int offset = 0, int? fromYear, int? toYear}) async {
    await listGate[type]?.future;
    return _ok('getAlbumList:${type.wire}:$offset', () {
      final list = switch (type) {
        AlbumListType.newest => [..._albums],
        // Home: what was played last, and the most played.
        AlbumListType.recent => [for (final i in [0, 7, 2]) if (i < _albums.length) _albums[i]],
        AlbumListType.frequent => [for (final i in [6, 8, 10]) if (i < _albums.length) _albums[i]],
        AlbumListType.alphabeticalByName => [..._albums]..sort((a, b) => a.title.compareTo(b.title)),
        AlbumListType.alphabeticalByArtist => [..._albums]..sort((a, b) => a.artist.compareTo(b.artist)),
        AlbumListType.byYear => [..._albums]..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0)),
        _ => [..._albums],
      };
      return list.skip(offset).take(size).toList();
    });
  }

  @override
  Future<AlbumDetail> getAlbum(String id) async => _ok('getAlbum:$id', () {
        final album = fakeAlbums.firstWhere(
          (a) => a.id == id,
          orElse: () => throw const ApiException(ApiErrorKind.notFound, 'gone'),
        );
        return AlbumDetail(album, [
          for (final t in fakeTracks)
            if (t.albumId == id) t,
        ]);
      });

  @override
  Future<List<Artist>> getArtists() async => _ok('getArtists', () => fakeArtists);

  @override
  Future<ArtistDetail> getArtist(String id) async => _ok('getArtist:$id', () {
        final artist = fakeArtists.firstWhere((a) => a.id == id);
        return ArtistDetail(artist, [
          for (final a in fakeAlbums)
            if (a.artistId == id) a,
        ]);
      });

  /// How many getScanStatus polls say "scanning" after a startScan (0: done at once).
  int scanPolls = 1;
  int _scanLeft = 0;

  @override
  Future<ScanStatus> startScan() async {
    calls.add('startScan');
    if (failWith != null) throw failWith!;
    _scanLeft = scanPolls;
    return ScanStatus(scanning: _scanLeft > 0, count: 10);
  }

  @override
  Future<ScanStatus> getScanStatus() async {
    calls.add('getScanStatus');
    if (failWith != null) throw failWith!;
    final scanning = _scanLeft > 0;
    if (scanning) _scanLeft--;
    return ScanStatus(scanning: scanning, count: fakeTracks.length);
  }

  /// What savePlayQueue stored (and getPlayQueue returns).
  ServerPlayQueue? serverQueue;

  /// Makes only savePlayQueue and getPlayQueue fail (a server that cannot keep a queue).
  ApiException? queueFailWith;
  final queueSaves = <({List<String> ids, String? current, Duration position})>[];

  @override
  Future<void> savePlayQueue(List<String> ids, {String? current, Duration position = Duration.zero}) async {
    calls.add('savePlayQueue');
    if (failWith != null) throw failWith!;
    if (queueFailWith != null) throw queueFailWith!;
    queueSaves.add((ids: ids, current: current, position: position));
    serverQueue = ServerPlayQueue(
      tracks: [for (final id in ids) fakeTracks.firstWhere((t) => t.id == id)],
      currentId: current,
      position: position,
      changed: DateTime.now(),
    );
  }

  @override
  Future<ServerPlayQueue?> getPlayQueue() async => _ok('getPlayQueue', () {
        if (queueFailWith != null) throw queueFailWith!;
        return serverQueue;
      });

  /// The playlists on this fake server and their songs (change them to set a test up;
  /// createPlaylist, updatePlaylist and deletePlaylist change them too).
  late final List<Playlist> playlists = [...fakePlaylists];
  late final Map<String, List<Track>> playlistSongs = {
    'pl-1': fakeTracks.take(2).toList(),
    'pl-2': fakeTracks.take(1).toList(),
  };
  int _newPlaylists = 0;

  Playlist _refreshed(Playlist p) => p.copyWith(songCount: playlistSongs[p.id]?.length ?? 0);

  @override
  Future<List<Playlist>> getPlaylists() async => _ok('getPlaylists', () => [for (final p in playlists) _refreshed(p)]);

  @override
  Future<PlaylistDetail> getPlaylist(String id) async => _ok('getPlaylist:$id', () {
        final p = playlists.firstWhere((p) => p.id == id);
        return PlaylistDetail(_refreshed(p), List.of(playlistSongs[id] ?? const []));
      });

  Track _song(String id) => fakeTracks.firstWhere((t) => t.id == id);

  @override
  Future<Playlist?> createPlaylist({String? name, String? playlistId, List<String> songIds = const []}) async =>
      _ok('createPlaylist', () {
        if (playlistId != null) {
          playlistSongs[playlistId] = [for (final id in songIds) _song(id)];
          return _refreshed(playlists.firstWhere((p) => p.id == playlistId));
        }
        final p = Playlist(id: 'pl-new-${++_newPlaylists}', name: name ?? 'Untitled', owner: 'josh');
        playlists.add(p);
        playlistSongs[p.id] = [for (final id in songIds) _song(id)];
        return _refreshed(p);
      });

  @override
  Future<void> updatePlaylist(
    String playlistId, {
    String? name,
    bool? isPublic,
    List<String> addSongIds = const [],
    List<int> removeIndexes = const [],
  }) async =>
      _ok('updatePlaylist', () {
        final at = playlists.indexWhere((p) => p.id == playlistId);
        playlists[at] = playlists[at].copyWith(name: name, isPublic: isPublic);
        final songs = playlistSongs.putIfAbsent(playlistId, () => []);
        for (final i in [...removeIndexes]..sort((a, b) => b.compareTo(a))) {
          songs.removeAt(i);
        }
        songs.addAll([for (final id in addSongIds) _song(id)]);
      });

  @override
  Future<void> deletePlaylist(String playlistId) async => _ok('deletePlaylist', () {
        playlists.removeWhere((p) => p.id == playlistId);
        playlistSongs.remove(playlistId);
      });

  @override
  Future<SearchResults> search(String query, {int artistCount = 5, int albumCount = 10, int songCount = 20}) async =>
      _ok('search', () {
        final q = query.toLowerCase();
        return SearchResults(
          artists: [for (final a in fakeArtists) if (a.name.toLowerCase().contains(q)) a],
          albums: [for (final a in fakeAlbums) if (a.title.toLowerCase().contains(q)) a],
          tracks: [for (final t in fakeTracks) if (t.title.toLowerCase().contains(q)) t],
        );
      });

  @override
  Future<List<Track>> getSongs({int offset = 0, int size = 500}) async =>
      _ok('getSongs:$offset', () => (songs ?? fakeTracks).skip(offset).take(size).toList());

  @override
  Future<List<Track>> getRandomSongs({int size = 30}) async => _ok('getRandomSongs', () => fakeTracks.take(size).toList());

  @override
  Future<List<Track>> getStarredSongs() async => _ok('getStarredSongs', () => [
        for (final t in songs ?? fakeTracks)
          if (t.starred) t,
      ]);

  @override
  Future<Lyrics?> getLyrics(String trackId) async {
    await lyricsGate[trackId]?.future;
    return _ok('getLyrics:$trackId', () => noLyricsFor.contains(trackId) ? null : placeholderLyrics);
  }

  @override
  Future<Uint8List> getCoverArt(String id, {int size = 300}) async =>
      throw const ApiException(ApiErrorKind.notFound, 'no cover in tests');

  @override
  Uri streamUri(String trackId) => Uri.parse('http://test.local/rest/stream?id=$trackId');

  @override
  Uri coverArtUri(String id, {int size = 300}) => Uri.parse('http://test.local/rest/getCoverArt?id=$id&size=$size');

  @override
  Future<void> star({String? trackId, String? albumId, String? artistId}) async {
    calls.add('star:${trackId ?? albumId ?? artistId}');
    final e = failStarWith;
    if (e != null) throw e;
  }

  @override
  Future<void> unstar({String? trackId, String? albumId, String? artistId}) async {
    calls.add('unstar:${trackId ?? albumId ?? artistId}');
    final e = failStarWith;
    if (e != null) throw e;
  }

  @override
  Future<void> scrobble(String trackId, {bool submission = false, DateTime? time}) async {
    calls.add('scrobble:$trackId:${submission ? 'submission' : 'nowplaying'}');
    final e = failScrobbleWith;
    if (e != null) throw e;
  }

  @override
  void close() {}
}
