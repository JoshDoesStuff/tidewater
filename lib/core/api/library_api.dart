import 'dart:typed_data';

import '../lyrics/lyrics.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
import '../models/server_play_queue.dart';
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
/// Where the server's library scan stands.
class ScanStatus {
  const ScanStatus({required this.scanning, this.count = 0});

  final bool scanning;
  final int count;
}

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

  /// Makes a playlist named [name] with [songIds] (private, until changed). With
  /// [playlistId] it instead replaces that playlist's songs with [songIds] (the way
  /// to reorder one). Returns the playlist when the server says which.
  Future<Playlist?> createPlaylist({String? name, String? playlistId, List<String> songIds = const []});

  /// Changes a playlist: its name, who can see it, songs to add (at the end) and
  /// songs to remove by their position in it.
  Future<void> updatePlaylist(
    String playlistId, {
    String? name,
    bool? isPublic,
    List<String> addSongIds = const [],
    List<int> removeIndexes = const [],
  });

  Future<void> deletePlaylist(String playlistId);

  Future<SearchResults> search(String query, {int artistCount = 5, int albumCount = 10, int songCount = 20});

  /// A page of every song in the library (Subsonic `search3` with an empty
  /// query, which Navidrome answers with all songs), in the server's order.
  Future<List<Track>> getSongs({int offset = 0, int size = 500});

  /// Random songs from the whole library (Shuffle all).
  Future<List<Track>> getRandomSongs({int size = 30});

  /// Every song the person has hearted (OpenSubsonic `getStarred2`).
  Future<List<Track>> getStarredSongs();

  /// Lyrics for a track from the server (OpenSubsonic `songLyrics`), or null
  /// when it has none or does not support them.
  Future<Lyrics?> getLyrics(String trackId);

  /// Cover art bytes for `getCoverArt`, scaled by the server to [size] px.
  Future<Uint8List> getCoverArt(String id, {int size = 300});

  /// URL of a cover (carries auth in the query), for things outside the app that
  /// load images themselves, such as the Windows media overlay.
  Uri coverArtUri(String id, {int size = 300});

  /// URL the playback engine streams from (carries auth in the query).
  Uri streamUri(String trackId);

  Future<void> star({String? trackId, String? albumId, String? artistId});
  Future<void> unstar({String? trackId, String? albumId, String? artistId});

  /// Saves the play queue (song ids in order, the current one and where in it, in
  /// ms) on the server so another client, or this one after a restart, can resume.
  Future<void> savePlayQueue(List<String> ids, {String? current, Duration position = Duration.zero});

  /// The queue the server holds for this user, or null when there is none (or
  /// the server cannot keep one).
  Future<ServerPlayQueue?> getPlayQueue();

  /// Starts a scan of the music folders on the server (admin accounts only).
  /// Returns whether it is scanning, and how many songs it has seen so far.
  Future<ScanStatus> startScan();

  Future<ScanStatus> getScanStatus();

  /// `submission: false` is "now playing"; `true` counts a play.
  Future<void> scrobble(String trackId, {bool submission = false, DateTime? time});

  void close();
}
