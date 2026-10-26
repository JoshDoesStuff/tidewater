import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/list_cache.dart';
import '../../core/api/server_config.dart';
import '../../core/models/server_play_queue.dart';
import '../../core/models/track.dart';
import '../../core/playback/play_queue.dart';
import '../../core/playback/resume.dart';
import '../../core/playback/saved_session.dart';
import 'list_cache_providers.dart';
import 'playback_providers.dart';
import 'queue_sync_status.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

// The queue used to live in the settings file, which is rewritten whole on every
// setting change (a volume tick rewrote the whole queue). It has its own file
// now; this key is only read once to move an old save over.
const _legacySessionKey = 'saved_session';
const _sessionFile = 'session';
const _volumeKey = 'player.volume';
const _shuffleKey = 'player.shuffle';
const _repeatKey = 'player.repeat';

/// How often the position goes to the server while playing.
const _serverPushEvery = Duration(seconds: 30);

/// The most songs of a queue sent to the server (around the current one when it is
/// longer). A queue that long goes in a POST body, not in the address.
const _serverQueueMax = 10000;

/// Saves the queue and position now, for the moment the window is closed (the
/// shell waits for it, briefly, before the app exits).
Future<void> flushSessionPersistence() => _flush?.call() ?? Future.value();
Future<void> Function()? _flush;

/// Identifies the server and user a saved queue belongs to.
String serverKeyOf(ServerConfig c) => '${c.baseUrl}|${c.username}';

/// Remembers the queue, position, shuffle, repeat and volume between launches
/// and puts them back (paused) when the app starts. Watch it once from the
/// shell.
///
/// The queue and position live on the server (Subsonic `savePlayQueue`): sent
/// when the queue changes, when playback pauses, when the track changes, when
/// the window is hidden and every 30 seconds while playing, and picked up at
/// launch. Once the server has proved it keeps the queue, nothing about it is
/// written to disk. A copy on this PC (its own file) is only written when
/// syncing is off or the server cannot hold the queue (or cannot be reached),
/// and it is what a launch with no connection falls back to. Shuffle, repeat and
/// volume are two flags and a number in the settings, written when they change.
/// Signing out forgets all of it.
final sessionPersistenceProvider = Provider<void>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final player = ref.read(playbackProvider.notifier);
  Timer? persistTimer;
  Timer? volumeDebounce;
  // The last file store of a signed-in server, to forget the queue on sign-out
  // (by then the store belongs to nobody).
  ListStore? lastStore;

  /// Whether the server has shown it keeps the queue: null until a push has
  /// been tried (and read back) in this run.
  bool? serverHolds;

  // What the server was last sent, to tell whether closing has anything left to save.
  List<String>? pushedIds;
  String? pushedCurrent;
  Duration pushedPosition = Duration.zero;

  void report(QueueSyncStatus status) => ref.read(queueSyncStatusProvider.notifier).set(status);

  String why(Object e) => e is ApiException ? e.message : 'the server could not be reached';

  String? lastReason;

  void writeLocal() {
    final config = ref.read(sessionProvider);
    if (config == null) return;
    final store = ref.read(listStoreProvider);
    lastStore = store;
    final s = ref.read(playbackProvider);
    if (s.queue.isEmpty) {
      unawaited(store.write(_sessionFile, const []));
      return;
    }
    report(
      QueueSyncStatus(
        QueueHome.thisPc,
        at: DateTime.now(),
        songs: s.queue.length,
        position: ref.read(positionProvider).value,
        reason: lastReason,
      ),
    );
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

  /// Sends the queue and position to the server; true when the server now holds
  /// them (the first time in a run it also reads them back to be sure).
  Future<bool> pushServer() async {
    if (ref.read(sessionProvider) == null) return false;
    if (!ref.read(syncPositionProvider)) {
      lastReason = 'keeping your place on the server is off';
      return false;
    }
    final s = ref.read(playbackProvider);
    var from = 0;
    var upTo = s.queue.length;
    if (upTo > _serverQueueMax) {
      from = (s.index - _serverQueueMax ~/ 2).clamp(0, upTo - _serverQueueMax);
      upTo = from + _serverQueueMax;
    }
    final ids = [for (final t in s.queue.sublist(from, upTo)) t.id];
    final at = ref.read(positionProvider).value;
    final clock = Stopwatch()..start();
    try {
      final api = ref.read(apiProvider);
      await api.savePlayQueue(ids, current: s.track?.id, position: at);
      pushedIds = ids;
      pushedCurrent = s.track?.id;
      pushedPosition = at;
      if (serverHolds == null && s.queue.isNotEmpty) {
        // Some servers accept the call and keep nothing: read it back once.
        final back = await api.getPlayQueue();
        serverHolds = back != null && back.currentId == s.track?.id;
        // The server has it, so an older copy on this PC would only be stale.
        if (serverHolds == true) {
          final store = ref.read(listStoreProvider);
          lastStore = store;
          unawaited(store.write(_sessionFile, const []));
        }
      } else if (s.queue.isNotEmpty) {
        serverHolds = true;
      }
      if (serverHolds == false) lastReason = 'the server accepted the queue but did not keep it';
      final holds = serverHolds ?? s.queue.isEmpty;
      if (holds && s.queue.isNotEmpty) {
        report(
          QueueSyncStatus(
            QueueHome.server,
            at: DateTime.now(),
            songs: upTo - from,
            position: at,
            took: clock.elapsed,
          ),
        );
      }
      return holds;
    } catch (e) {
      serverHolds = false;
      lastReason = why(e);
      return false;
    }
  }

  /// True when the server holds this exact queue, song and (within a second or
  /// two) position, so there is nothing new to send.
  bool upToDate() {
    if (serverHolds != true || !ref.read(syncPositionProvider)) return false;
    final s = ref.read(playbackProvider);
    final sent = pushedIds;
    if (sent == null || s.track?.id != pushedCurrent) return false;
    if ((ref.read(positionProvider).value - pushedPosition).abs() > const Duration(milliseconds: 1500)) return false;
    var from = 0;
    var upTo = s.queue.length;
    if (upTo > _serverQueueMax) {
      from = (s.index - _serverQueueMax ~/ 2).clamp(0, upTo - _serverQueueMax);
      upTo = from + _serverQueueMax;
    }
    if (upTo - from != sent.length) return false;
    for (var i = 0; i < sent.length; i++) {
      if (s.queue[from + i].id != sent[i]) return false;
    }
    return true;
  }

  /// Keeps the queue: on the server when it holds it, otherwise on this PC. A
  /// save that is already on its way is joined, not repeated (hiding the window
  /// and closing it both ask, a moment apart, and two copies of a big queue only
  /// slow the server down).
  Future<void>? saving;
  Future<void> persist() {
    return saving ??= () async {
      try {
        if (ref.read(sessionProvider) == null) return;
        if (ref.read(syncPositionProvider) && await pushServer()) return;
        writeLocal();
      } finally {
        saving = null;
      }
    }();
  }

  void persistSoon() {
    persistTimer?.cancel();
    persistTimer = Timer(const Duration(seconds: 2), () => unawaited(persist()));
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
    var local = SavedSession.decode(
      stored == null || stored.isEmpty ? prefs.getString(_legacySessionKey) : jsonEncode(stored.first),
    );
    if (prefs.containsKey(_legacySessionKey)) unawaited(prefs.remove(_legacySessionKey));
    if (local != null && local.server != key) local = null;
    ServerPlayQueue? remote;
    if (ref.read(syncPositionProvider)) {
      try {
        remote = await ref.read(apiProvider).getPlayQueue().timeout(const Duration(seconds: 4));
      } catch (_) {
        remote = null; // offline, slow or unsupported: the copy on this PC it is
      }
    }
    // Something may have started playing while the server was answering.
    if (ref.read(playbackProvider).queue.isNotEmpty) return;
    final repeatName = prefs.getString(_repeatKey);
    final chosen = chooseResume(
      serverKey: key,
      local: local,
      server: remote,
      volume: prefs.getDouble(_volumeKey) ?? .7,
      shuffled: prefs.getBool(_shuffleKey) ?? false,
      repeat: LoopMode.values.firstWhere((m) => m.name == repeatName, orElse: () => LoopMode.off),
    );
    if (chosen == null) return;
    if (remote != null && !remote.isEmpty) {
      serverHolds = true;
      report(
        QueueSyncStatus(
          QueueHome.server,
          at: remote.changed?.toLocal(),
          songs: remote.tracks.length,
          position: remote.position,
        ),
      );
    }
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
    if (next.shuffle != prev.shuffle) unawaited(prefs.setBool(_shuffleKey, next.shuffle));
    if (next.repeat != prev.repeat) unawaited(prefs.setString(_repeatKey, next.repeat.name));
    final queueChanged =
        prev.queue.length != next.queue.length || prev.track?.id != next.track?.id || !_sameOrder(prev.queue, next.queue);
    // Pausing is when the position is final, and the window may be closed a moment
    // later: save at once. Queue changes wait a moment, in case more follow.
    final paused = prev.playing && !next.playing;
    if (paused) {
      persistTimer?.cancel();
      unawaited(persist());
    } else if (queueChanged) {
      persistSoon();
    }
  });

  // Signing out forgets the queue; signing in to a server restores its own.
  ref.listen(sessionProvider, (prev, next) {
    if (next == null) {
      unawaited(prefs.remove(_legacySessionKey));
      final store = lastStore;
      if (store != null) unawaited(store.write(_sessionFile, const []));
      serverHolds = null;
    } else if (prev == null) {
      unawaited(restore());
    }
  });

  // While playing, the position goes to the server now and then.
  final ticker = Timer.periodic(_serverPushEvery, (_) {
    if (ref.read(playbackProvider).playing) unawaited(persist());
  });

  // Hiding or closing the window is the last chance to keep the position.
  final observer = _LifecycleSaver(() => unawaited(persist()));
  _flush = () async {
    persistTimer?.cancel();
    // Paused (or just saved): the server already has all of it, so closing need not wait.
    if (upToDate()) return;
    await persist();
  };
  WidgetsBinding.instance.addObserver(observer);

  ref.onDispose(() {
    _flush = null;
    ticker.cancel();
    persistTimer?.cancel();
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
