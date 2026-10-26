import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/list_cache.dart';
import '../../core/api/server_config.dart';
import '../../core/models/server_play_queue.dart';
import '../../core/models/track.dart';
import '../../core/playback/resume.dart';
import '../../core/playback/saved_session.dart';
import 'list_cache_providers.dart';
import 'playback_providers.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

// The queue used to live in the settings file, which is rewritten whole on every
// setting change (a volume tick rewrote the whole queue). It has its own file now;
// this key is only read once to move an old save over.
const _legacySessionKey = 'saved_session';
const _sessionFile = 'session';
const _volumeKey = 'player.volume';

/// How often the position goes to the server while playing. (It used to be
/// written to disk every 5 seconds, together with the whole queue.)
const _serverPushEvery = Duration(seconds: 30);

/// The server keeps about this many songs of a queue (around the current one),
/// which keeps the request small.
const _serverQueueMax = 200;

/// Identifies the server and user a saved queue belongs to.
String serverKeyOf(ServerConfig c) => '${c.baseUrl}|${c.username}';

/// Remembers the queue, position, shuffle, repeat and volume between launches
/// and puts them back (paused) when the app starts. Watch it once from the
/// shell.
///
/// The queue is saved to disk when it changes (and the position when playback
/// pauses, the track changes or the window is hidden), never on a timer. While
/// playing, the position goes to the server every 30 seconds instead
/// (Subsonic `savePlayQueue`), and at launch the server's copy is used when it
/// is newer. Signing out forgets all of it.
final sessionPersistenceProvider = Provider<void>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final player = ref.read(playbackProvider.notifier);
  Timer? debounce;
  Timer? serverDebounce;
  Timer? volumeDebounce;
  // The last file store of a signed-in server, to forget the queue on sign-out
  // (by then the store belongs to nobody).
  ListStore? lastStore;

  void save() {
    final config = ref.read(sessionProvider);
    if (config == null) return;
    final store = ref.read(listStoreProvider);
    lastStore = store;
    final s = ref.read(playbackProvider);
    if (s.queue.isEmpty) {
      unawaited(store.write(_sessionFile, const []));
      return;
    }
    final saved = SavedSession(
        server: serverKeyOf(config),
        tracks: s.queue,
        index: s.index,
        position: ref.read(positionProvider).value,
        shuffled: s.shuffle,
        repeat: s.repeat,
        volume: s.volume,
        savedAt: DateTime.now(),
      ).encode();
    // Written only when it differs from the file (see ListCache.write).
    unawaited(store.write(_sessionFile, [jsonDecode(saved) as Map<String, dynamic>]));
  }

  void saveSoon() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 800), save);
  }

  /// Sends the queue and position to the server (quietly: a server that cannot
  /// keep one, or no connection, just means no copy there).
  Future<void> pushServer() async {
    if (ref.read(sessionProvider) == null || !ref.read(syncPositionProvider)) return;
    final s = ref.read(playbackProvider);
    if (s.queue.isEmpty) return;
    var from = 0;
    var upTo = s.queue.length;
    if (upTo > _serverQueueMax) {
      from = (s.index - _serverQueueMax ~/ 2).clamp(0, upTo - _serverQueueMax);
      upTo = from + _serverQueueMax;
    }
    try {
      await ref
          .read(apiProvider)
          .savePlayQueue(
            [for (final t in s.queue.sublist(from, upTo)) t.id],
            current: s.track?.id,
            position: ref.read(positionProvider).value,
          );
    } catch (_) {
      // Nothing to do: the local copy is still there.
    }
  }

  void pushServerSoon() {
    serverDebounce?.cancel();
    serverDebounce = Timer(const Duration(seconds: 2), pushServer);
  }

  Future<void> restore() async {
    final config = ref.read(sessionProvider);
    if (config == null) return;
    final s = ref.read(playbackProvider);
    if (s.queue.isNotEmpty) return;
    final key = serverKeyOf(config);
    final store = ref.read(listStoreProvider);
    lastStore = store;
    final stored = await store.read(_sessionFile);
    var local = SavedSession.decode(stored == null || stored.isEmpty ? prefs.getString(_legacySessionKey) : jsonEncode(stored.first));
    if (prefs.containsKey(_legacySessionKey)) unawaited(prefs.remove(_legacySessionKey));
    if (local != null && local.server != key) local = null;
    ServerPlayQueue? remote;
    if (ref.read(syncPositionProvider)) {
      try {
        remote = await ref.read(apiProvider).getPlayQueue().timeout(const Duration(seconds: 4));
      } catch (_) {
        remote = null; // offline, slow or unsupported: the local copy it is
      }
    }
    // Something may have started playing while the server was answering.
    if (ref.read(playbackProvider).queue.isNotEmpty) return;
    final chosen = chooseResume(serverKey: key, local: local, server: remote, volume: prefs.getDouble(_volumeKey) ?? .7);
    if (chosen == null) return;
    await player.restore(chosen);
  }

  // The volume applies even before anything is queued.
  final volume = prefs.getDouble(_volumeKey);
  if (volume != null) unawaited(player.setVolume(volume));
  unawaited(restore());

  ref.listen(playbackProvider, (prev, next) {
    if (prev == null) return;
    if (next.volume != prev.volume) {
      // Dragging the slider changes it dozens of times a second; write once it settles.
      volumeDebounce?.cancel();
      volumeDebounce = Timer(const Duration(milliseconds: 700), () => prefs.setDouble(_volumeKey, ref.read(playbackProvider).volume));
    }
    final queueChanged =
        prev.queue.length != next.queue.length || prev.track?.id != next.track?.id || !_sameOrder(prev.queue, next.queue);
    final changed = queueChanged || next.shuffle != prev.shuffle || next.repeat != prev.repeat || next.volume != prev.volume;
    if (changed) saveSoon();
    if (queueChanged) pushServerSoon();
    // Pausing is when the position is final.
    if (prev.playing && !next.playing) {
      saveSoon();
      pushServerSoon();
    }
  });

  // Signing out forgets the queue; signing in to a server restores its own.
  ref.listen(sessionProvider, (prev, next) {
    if (next == null) {
      unawaited(prefs.remove(_legacySessionKey));
      final store = lastStore;
      if (store != null) unawaited(store.write(_sessionFile, const []));
    } else if (prev == null) {
      unawaited(restore());
    }
  });

  // While playing, the position goes to the server now and then.
  final ticker = Timer.periodic(_serverPushEvery, (_) {
    if (ref.read(playbackProvider).playing) unawaited(pushServer());
  });

  // Hiding or closing the window is the last chance to keep the position.
  final observer = _LifecycleSaver(() {
    save();
    unawaited(pushServer());
  });
  WidgetsBinding.instance.addObserver(observer);

  ref.onDispose(() {
    ticker.cancel();
    debounce?.cancel();
    serverDebounce?.cancel();
    volumeDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(observer);
  });
});

class _LifecycleSaver with WidgetsBindingObserver {
  _LifecycleSaver(this.onLeave);

  final VoidCallback onLeave;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      onLeave();
    }
  }
}

bool _sameOrder(List<Track> a, List<Track> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}
