import 'album.dart';
import 'artist.dart';
import 'json_util.dart';
import 'track.dart';

class SearchResults {
  const SearchResults({this.artists = const [], this.albums = const [], this.tracks = const []});

  factory SearchResults.fromJson(Map<String, dynamic> j) => SearchResults(
        artists: [for (final a in asObjects(j['artist'])) Artist.fromJson(a)],
        albums: [for (final a in asObjects(j['album'])) Album.fromJson(a)],
        tracks: [for (final s in asObjects(j['song'])) Track.fromJson(s)],
      );

  final List<Artist> artists;
  final List<Album> albums;
  final List<Track> tracks;

  bool get isEmpty => artists.isEmpty && albums.isEmpty && tracks.isEmpty;
}
