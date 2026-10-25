import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_config.dart';
import '../../core/models/track.dart';
import '../../core/playback/saved_session.dart';
import 'playback_providers.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

const _sessionKey = 'saved_session';
const _volumeKey = 'player.volume';

/// Identifies the server and user a saved queue belongs to.
String serverKeyOf(ServerConfig c) => '${c.baseUrl}|${c.username}';

/// Remembers the queue, position, shuffle, repeat and volume between launches
/// and puts them back (paused) when the app starts. Watch it once from the
/// shell. The queue is saved shortly after it changes and the position every
/// few seconds while playing; signing out forgets it.
final sessionPersistenceProvider = Provider<void>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final player = ref.read(playbackProvider.notifier);
  Timer? debounce;

  void save() {
    final config = ref.read(sessionProvider);
    if (config == null) return;
    final s = ref.read(playbackProvider);
    if (s.queue.isEmpty) {
      prefs.remove(_sessionKey);
      return;
    }
    prefs.setString(
      _sessionKey,
      SavedSession(
        server: serverKeyOf(config),
        tracks: s.queue,
        index: s.index,
        position: ref.read(positionProvider).value,
        shuffled: s.shuffle,
        repeat: s.repeat,
        volume: s.volume,
      ).encode(),
    );
  }

  void saveSoon() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 800), save);
  }

  Future<void> restore() async {
    final config = ref.read(sessionProvider);
    if (config == null) return;
    final s = ref.read(playbackProvider);
    if (s.queue.isNotEmpty) return;
    final saved = SavedSession.decode(prefs.getString(_sessionKey));
    if (saved == null || saved.server != serverKeyOf(config)) return;
    await player.restore(saved);
  }

  // The volume applies even before anything is queued.
  final volume = prefs.getDouble(_volumeKey);
  if (volume != null) unawaited(player.setVolume(volume));
  unawaited(restore());

  ref.listen(playbackProvider, (prev, next) {
    if (prev == null) return;
    if (next.volume != prev.volume) prefs.setDouble(_volumeKey, next.volume);
    final queueChanged = prev.queue.length != next.queue.length || prev.track?.id != next.track?.id || !_sameOrder(prev.queue, next.queue);
    final changed = queueChanged || next.shuffle != prev.shuffle || next.repeat != prev.repeat || next.volume != prev.volume;
    if (changed) saveSoon();
    // Pausing is when the position is final.
    if (prev.playing && !next.playing) saveSoon();
  });

  // Signing out forgets the queue; signing in to a server restores its own.
  ref.listen(sessionProvider, (prev, next) {
    if (next == null) {
      prefs.remove(_sessionKey);
    } else if (prev == null) {
      unawaited(restore());
    }
  });

  final ticker = Timer.periodic(const Duration(seconds: 5), (_) {
    if (ref.read(playbackProvider).playing) save();
  });
ref.onDispose(() {    ticker.cancel();    debounce?.cancel();  });});

bool _sameOrder(List<Track> a, List<Track> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}
