import 'album.dart';
import 'json_util.dart';

class Artist {
  const Artist({required this.id, required this.name, this.albumCount = 0, this.coverArt, this.starred = false});

  factory Artist.fromJson(Map<String, dynamic> j) => Artist(
        id: asString(j['id']) ?? '',
        name: asName(j['name']) ?? 'Unknown artist',
        albumCount: asInt(j['albumCount']) ?? 0,
        coverArt: asString(j['coverArt']),
        starred: j['starred'] != null,
      );

  final String id;
  final String name;
  final int albumCount;
  final String? coverArt;
  final bool starred;

  @override
  bool operator ==(Object other) => other is Artist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ArtistDetail {
  const ArtistDetail(this.artist, this.albums);

  factory ArtistDetail.fromJson(Map<String, dynamic> j) =>
      ArtistDetail(Artist.fromJson(j), [for (final a in asObjects(j['album'])) Album.fromJson(a)]);

  final Artist artist;
  final List<Album> albums;
}
