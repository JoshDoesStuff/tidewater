import '../models/server_play_queue.dart';
import '../models/track.dart';
import 'play_queue.dart';
import 'saved_session.dart';

/// How far apart the server's and this device's clocks may be before one copy
/// counts as newer.
const _clockSlack = Duration(seconds: 5);

/// Picks what to put back at launch from the copy saved on this device and the
/// one the server holds (null when there is none). The server's copy wins when
/// it is newer: it was saved while playing, so its position is closer to where
/// you stopped, and it may come from another device. The player settings
/// (shuffle, repeat, volume) always come from this device when it has them.
SavedSession? chooseResume({
  required String serverKey,
  SavedSession? local,
  ServerPlayQueue? server,
  double volume = .7,
  bool shuffled = false,
  LoopMode repeat = LoopMode.off,
}) {
  final remote = server == null || server.isEmpty ? null : server;
  if (remote == null) return local;
  final fromServer = SavedSession(
    server: serverKey,
    tracks: remote.tracks,
    index: remote.currentIndex,
    position: remote.position,
    shuffled: local?.shuffled ?? shuffled,
    repeat: local?.repeat ?? repeat,
    volume: local?.volume ?? volume,
    savedAt: remote.changed,
  );
  if (local == null) return fromServer;

  final localTime = local.savedAt;
  final serverNewer = remote.changed != null && (localTime == null || remote.changed!.isAfter(localTime.add(_clockSlack)));
  if (!serverNewer) return local;

  // The same queue: keep this device's order, take the server's place in it.
  if (_sameIds(local.tracks, remote.tracks)) {
    final at = local.tracks.indexWhere((t) => t.id == remote.currentId);
    return SavedSession(
      server: local.server,
      tracks: local.tracks,
      index: at < 0 ? local.index : at,
      position: remote.position,
      shuffled: local.shuffled,
      repeat: local.repeat,
      volume: local.volume,
      savedAt: remote.changed,
    );
  }
  return fromServer;
}

bool _sameIds(List<Track> a, List<Track> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}
