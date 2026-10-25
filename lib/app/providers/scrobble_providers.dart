import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/library_api.dart';
import '../../core/playback/scrobble_tracker.dart';
import 'library_providers.dart';
import 'playback_providers.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

/// Reports playback to the server: "now playing" when a track starts, and a
/// counted play after half the track or four minutes (see [ScrobbleTracker]).
/// Failed submissions are kept and retried every minute while the app runs.
/// Watch it once from the shell to keep it alive.
final scrobbleServiceProvider = Provider<void>((ref) {
  final tracker = ScrobbleTracker();
  final pending = <ScrobbleEvent>[];
  var disposed = false;

  Future<void> send(ScrobbleEvent e) async {
    if (!ref.read(scrobbleEnabledProvider) || ref.read(sessionProvider) == null) return;
    try {
      await ref.read(apiProvider).scrobble(e.track.id, submission: e.submission, time: e.startedAt);
      if (e.submission && !disposed) {
        // The play now exists on the server: Home's rows should show it.
        ref.invalidate(albumRowProvider(AlbumListType.recent));
        ref.invalidate(albumRowProvider(AlbumListType.frequent));
      }
    } catch (_) {
      // A "now playing" that fails is simply stale; a counted play is worth
      // keeping until the server is back.
      if (e.submission && pending.length < 100) pending.add(e);
    }
  }

  void sendAll(List<ScrobbleEvent> events) {
    for (final e in events) {
      unawaited(send(e));
    }
  }

  ref.listen(playbackProvider.select((s) => (s.track?.id, s.playing)), (_, next) {
    final s = ref.read(playbackProvider);
    sendAll(tracker.onTrack(s.track, playing: s.playing));
  }, fireImmediately: true);

  final position = ref.watch(positionProvider);
  void onPosition() => sendAll(tracker.onPosition(position.value));
  position.addListener(onPosition);

  final retry = Timer.periodic(const Duration(minutes: 1), (_) {
    if (pending.isEmpty) return;
    final batch = [...pending];
    pending.clear();
    sendAll(batch);
  });

  ref.onDispose(() {
    disposed = true;
    retry.cancel();
    position.removeListener(onPosition);
  });
});
