import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cover_cache.dart';
import 'cover_providers.dart';
import 'library_providers.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

/// How far saving the Library's covers to disk has got.
class CoverPrecache {
  const CoverPrecache({
    this.total = 0,
    this.done = 0,
    this.running = false,
    this.finished = false,
    this.firstRun = false,
    this.hidden = false,
  });

  final int total;
  final int done;
  final bool running;
  final bool finished;

  /// No covers were saved for this server before: the progress shows (the first launch).
  final bool firstRun;

  /// The user sent it to the background.
  final bool hidden;

  double get fraction => total == 0 ? 0 : (done / total).clamp(0, 1);

  CoverPrecache copyWith({int? total, int? done, bool? running, bool? finished, bool? firstRun, bool? hidden}) =>
      CoverPrecache(
        total: total ?? this.total,
        done: done ?? this.done,
        running: running ?? this.running,
        finished: finished ?? this.finished,
        firstRun: firstRun ?? this.firstRun,
        hidden: hidden ?? this.hidden,
      );
}

/// Saves every album's and song's grid cover (300 px) to the disk cache, so browsing never waits
/// on the network: on a machine with an empty cache a 5000-song Library downloaded its covers
/// while it was scrolled, a few at a time, and cards waited on them for seconds.
///
/// Gentle on the disk: each cover is written once, whole, through the cache's write-then-rename
/// (no partial rewrites); a cover already on disk is only checked for (a file lookup, nothing
/// read or written), so later launches cost a few thousand lookups and download only what is
/// new. A 5000-cover Library is roughly 150-250 MB, written once. Four downloads at a time, and
/// covers a card on screen asks for go ahead of these (the cache serves the newest request first).
class CoverPrecacheNotifier extends Notifier<CoverPrecache> {
  static const workers = 4;
  var _generation = 0;

  @override
  CoverPrecache build() {
    final config = ref.watch(sessionProvider);
    final generation = ++_generation;
    if (config != null) {
      final key = 'covers_saved_${CoverCache.serverFolder(config.baseUrl)}';
      final prefs = ref.read(sharedPreferencesProvider);
      final firstRun = !(prefs.getBool(key) ?? false);
      Future.microtask(() => _run(generation, key, firstRun));
    }
    return const CoverPrecache();
  }

  /// Hides the progress (it carries on in the background).
  void hide() => state = state.copyWith(hidden: true);

  bool _stale(int generation) => !ref.mounted || generation != _generation;

  Future<void> _run(int generation, String key, bool firstRun) async {
    final store = ref.read(coverCacheProvider);
    if (store is! CoverCache) return;
    state = CoverPrecache(running: true, firstRun: firstRun);

    // The full lists, as the Library pages load them (from the saved copy first).
    final albums = await _whenComplete<LibraryAlbums>(
      (onValue) => ref.listen(
        libraryAlbumsProvider(LibrarySort.recentlyAdded),
        (_, next) => onValue(next),
        fireImmediately: true,
      ),
      (v) => v.complete,
    );
    if (_stale(generation)) return;
    final songs = await _whenComplete<LibrarySongs>(
      (onValue) => ref.listen(libraryAllSongsProvider, (_, next) => onValue(next), fireImmediately: true),
      (v) => v.complete,
    );
    if (_stale(generation)) return;
    final ids = <String>{
      for (final a in albums?.albums ?? const []) ?a.coverArt,
      for (final s in songs?.songs ?? const []) ?s.coverArt,
    }.toList();
    state = state.copyWith(total: ids.length, done: 0);

    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (next < ids.length) {
        if (_stale(generation)) return;
        final id = ids[next++];
        try {
          if (!await store.isSaved(id)) await store.get(id);
        } catch (_) {
          // A cover the server cannot give: skipped, tried again next launch.
        }
        done++;
        // Progress at most every 25 covers (each update rebuilds the progress).
        if (done % 25 == 0 || done == ids.length) {
          if (_stale(generation)) return;
          state = state.copyWith(done: done);
        }
      }
    }

    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    if (_stale(generation)) return;
    await ref.read(sharedPreferencesProvider).setBool(key, true);
    if (_stale(generation)) return;
    state = state.copyWith(done: ids.length, running: false, finished: true);
  }

  /// Waits until a list provider says it has everything (null on an error, or after five minutes).
  Future<T?> _whenComplete<T>(
    ProviderSubscription<AsyncValue<T>> Function(void Function(AsyncValue<T>) onValue) listen,
    bool Function(T) complete,
  ) async {
    final done = Completer<T?>();
    final sub = listen((next) {
      final v = next.value;
      if (v != null && complete(v) && !done.isCompleted) done.complete(v);
      if (next.hasError && !done.isCompleted) done.complete(null);
    });
    try {
      return await done.future.timeout(const Duration(minutes: 5), onTimeout: () => null);
    } finally {
      sub.close();
    }
  }
}

final coverPrecacheProvider = NotifierProvider<CoverPrecacheNotifier, CoverPrecache>(CoverPrecacheNotifier.new);
