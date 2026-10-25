import 'dart:typed_data';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
import '../models/track.dart';

/// What the server told us about itself (`ping` + `getOpenSubsonicExtensions`).
class ServerInfo {
  const ServerInfo({
    required this.apiVersion,
    this.serverName,
    this.serverVersion,
    this.openSubsonic = false,
    this.extensions = const {},
  });

  final String apiVersion;
  final String? serverName;
  final String? serverVersion;
  final bool openSubsonic;
  final Set<String> extensions;

  bool supports(String extension) => extensions.contains(extension);

  ServerInfo withExtensions(Set<String> extensions) => ServerInfo(
        apiVersion: apiVersion,
        serverName: serverName,
        serverVersion: serverVersion,
        openSubsonic: openSubsonic,
        extensions: extensions,
      );
}

/// `getAlbumList2` orderings.
enum AlbumListType {
  newest('newest'),
  frequent('frequent'),
  recent('recent'),
  random('random'),
  alphabeticalByName('alphabeticalByName'),
  alphabeticalByArtist('alphabeticalByArtist'),
  starred('starred'),
  byYear('byYear');

  const AlbumListType(this.wire);
  final String wire;
}

/// The server operations the UI uses. [OpenSubsonicClient] talks to a real
/// server; tests supply an in-memory one.
abstract class LibraryApi {
  Future<ServerInfo> ping();

  Future<List<Album>> getAlbumList(
    AlbumListType type, {
    int size = 20,
    int offset = 0,
    int? fromYear,
    int? toYear,
  });

  Future<AlbumDetail> getAlbum(String id);

  /// Every artist, flattened out of the server's alphabetical index buckets.
  Future<List<Artist>> getArtists();

  Future<ArtistDetail> getArtist(String id);

  Future<List<Playlist>> getPlaylists();

  Future<PlaylistDetail> getPlaylist(String id);

  Future<SearchResults> search(String query, {int artistCount = 5, int albumCount = 10, int songCount = 20});

  /// Random songs from the whole library (Shuffle all).
  Future<List<Track>> getRandomSongs({int size = 30});

  /// Cover art bytes for `getCoverArt`, scaled by the server to [size] px.
  Future<Uint8List> getCoverArt(String id, {int size = 300});

  /// URL the playback engine streams from (carries auth in the query).
  Uri streamUri(String trackId);

  Future<void> star({String? trackId, String? albumId, String? artistId});
  Future<void> unstar({String? trackId, String? albumId, String? artistId});

  /// `submission: false` is "now playing"; `true` counts a play.
  Future<void> scrobble(String trackId, {bool submission = false, DateTime? time});

  void close();
}
