import 'json_util.dart';
import 'track.dart';

/// The play queue a server keeps for the user (Subsonic `getPlayQueue`): the
/// queued songs, which one is current, how far in, and when it last changed.
/// Any client of that user can pick it up where another left off.
class ServerPlayQueue {
  const ServerPlayQueue({required this.tracks, required this.currentId, required this.position, this.changed});

  factory ServerPlayQueue.fromJson(Map<String, dynamic> j) => ServerPlayQueue(
        tracks: [for (final s in asObjects(j['entry'])) Track.fromJson(s)],
        currentId: asString(j['current']),
        position: Duration(milliseconds: asInt(j['position']) ?? 0),
        changed: asDate(j['changed']),
      );

  final List<Track> tracks;
  final String? currentId;
  final Duration position;
  final DateTime? changed;

  bool get isEmpty => tracks.isEmpty;

  /// Index of the current song in [tracks] (0 when it is not named or not there).
  int get currentIndex {
    final i = tracks.indexWhere((t) => t.id == currentId);
    return i < 0 ? 0 : i;
  }
}
