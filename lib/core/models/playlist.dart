import 'json_util.dart';
import 'track.dart';

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.owner,
    this.songCount = 0,
    this.duration = Duration.zero,
    this.coverArt,
  });

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: asString(j['id']) ?? '',
        name: asString(j['name']) ?? 'Untitled',
        owner: asString(j['owner']),
        songCount: asInt(j['songCount']) ?? 0,
        duration: asSeconds(j['duration']),
        coverArt: asString(j['coverArt']),
      );

  final String id;
  final String name;
  final String? owner;
  final int songCount;
  final Duration duration;
  final String? coverArt;
}

class PlaylistDetail {
  const PlaylistDetail(this.playlist, this.tracks);

  factory PlaylistDetail.fromJson(Map<String, dynamic> j) =>
      PlaylistDetail(Playlist.fromJson(j), [for (final s in asObjects(j['entry'])) Track.fromJson(s)]);

  final Playlist playlist;
  final List<Track> tracks;
}
