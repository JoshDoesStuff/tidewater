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
    this.isPublic = false,
    this.comment,
    this.readonly = false,
  });

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: asString(j['id']) ?? '',
        name: asString(j['name']) ?? 'Untitled',
        owner: asString(j['owner']),
        songCount: asInt(j['songCount']) ?? 0,
        duration: asSeconds(j['duration']),
        coverArt: asString(j['coverArt']),
        isPublic: j['public'] == true,
        comment: asString(j['comment']),
        readonly: j['readonly'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (owner != null) 'owner': owner,
        'songCount': songCount,
        'duration': duration.inSeconds,
        if (coverArt != null) 'coverArt': coverArt,
        if (isPublic) 'public': true,
        if (comment != null) 'comment': comment,
        if (readonly) 'readonly': true,
      };

  Playlist copyWith({String? name, bool? isPublic, int? songCount, Duration? duration}) => Playlist(
        id: id,
        name: name ?? this.name,
        owner: owner,
        songCount: songCount ?? this.songCount,
        duration: duration ?? this.duration,
        coverArt: coverArt,
        isPublic: isPublic ?? this.isPublic,
        comment: comment,
        readonly: readonly,
      );

  /// Whether [username] may change this playlist: not a smart playlist (the
  /// server builds those from rules and marks them read-only), and their own.
  bool canEdit(String username) => !readonly && (owner == null || owner!.isEmpty || owner == username);

  final String id;
  final String name;
  final String? owner;
  final int songCount;
  final Duration duration;
  final String? coverArt;

  /// Visible to the other users of the server.
  final bool isPublic;
  final String? comment;

  /// The server says nobody can edit it (a smart playlist).
  final bool readonly;
}

class PlaylistDetail {
  const PlaylistDetail(this.playlist, this.tracks);

  factory PlaylistDetail.fromJson(Map<String, dynamic> j) =>
      PlaylistDetail(Playlist.fromJson(j), [for (final s in asObjects(j['entry'])) Track.fromJson(s)]);

  final Playlist playlist;
  final List<Track> tracks;
}
