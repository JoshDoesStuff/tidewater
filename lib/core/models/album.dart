import 'json_util.dart';
import 'track.dart';

/// A music album as the UI needs it. Plain Dart so `core/` stays Flutter-free.
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId,
    this.coverArt,
    this.year,
    this.genre,
    this.songCount = 0,
    this.duration = Duration.zero,
    this.created,
    this.playCount = 0,
    this.starred = false,
  });

  factory Album.fromJson(Map<String, dynamic> j) => Album(
        id: asString(j['id']) ?? '',
        title: asString(j['name'] ?? j['title'] ?? j['album']) ?? 'Unknown album',
        artist: asString(j['artist']) ?? 'Unknown artist',
        artistId: asString(j['artistId']),
        coverArt: asString(j['coverArt']),
        year: asInt(j['year']),
        genre: asString(j['genre']),
        songCount: asInt(j['songCount']) ?? 0,
        duration: asSeconds(j['duration']),
        created: asDate(j['created']),
        playCount: asInt(j['playCount']) ?? 0,
        starred: j['starred'] != null,
      );

  /// Back to the shape the server sends, so [Album.fromJson] reads it again
  /// (the list cache).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': title,
        'artist': artist,
        if (artistId != null) 'artistId': artistId,
        if (coverArt != null) 'coverArt': coverArt,
        if (year != null) 'year': year,
        if (genre != null) 'genre': genre,
        'songCount': songCount,
        'duration': duration.inSeconds,
        if (created != null) 'created': created!.toUtc().toIso8601String(),
        'playCount': playCount,
        if (starred) 'starred': true,
      };

  final String id;
  final String title;
  final String artist;
  final String? artistId;

  /// Cover-art id for `getCoverArt`; null when the album has none.
  final String? coverArt;
  final int? year;
  final String? genre;
  final int songCount;
  final Duration duration;
  final DateTime? created;
  final int playCount;
  final bool starred;

  @override
  bool operator ==(Object other) => other is Album && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// An album with its tracks (`getAlbum`).
class AlbumDetail {
  const AlbumDetail(this.album, this.tracks);

  factory AlbumDetail.fromJson(Map<String, dynamic> j) {
    final album = Album.fromJson(j);
    return AlbumDetail(album, [
      for (final s in asObjects(j['song'])) Track.fromJson(s, fallbackAlbum: album),
    ]);
  }

  final Album album;
  final List<Track> tracks;
}
