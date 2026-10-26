import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../../core/models/track.dart';
import '../../core/playback/playback_engine.dart';
import '../../core/playback/saved_session.dart';
import '../../core/playback/simulated_engine.dart';
import '../../core/playback/visualizer_source.dart';
import 'cover_providers.dart';
import 'library_providers.dart';
import 'session_providers.dart';
import 'ui_providers.dart';

/// The engine behind the UI. A simulated one until real playback lands (M3).
final playbackEngineProvider = Provider<PlaybackEngine>((ref) {
  final engine = SimulatedEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

class PlaybackController extends Notifier<PlaybackState> {
  PlaybackEngine get _engine => ref.read(playbackEngineProvider);
  final _random = math.Random();

  @override
  PlaybackState build() {
    final engine = ref.watch(playbackEngineProvider);
    final sub = engine.states.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return engine.state;
  }

  /// Runs a server request that ends in playback; a failure becomes a toast
  /// instead of an unhandled error.
  Future<void> _load(Future<List<Track>> Function() tracks, {int index = 0, bool shuffle = false}) async {
    try {
      final queue = await tracks();
      if (queue.isEmpty) {
        ref.read(toastProvider.notifier).show('Nothing to play there.');
        return;
      }
      ref.read(likedProvider.notifier).seed(queue);
      // A shuffled play starts anywhere, not always on the first track.
      final start = shuffle && index == 0 ? _random.nextInt(queue.length) : index;
      await _engine.playQueue(queue, index: start, shuffle: shuffle);
    } on ApiException catch (e) {
      ref.read(toastProvider.notifier).show(
            e.isOffline ? 'Can\'t reach the server. Check your connection.' : e.message,
            error: true,
          );
    }
  }

  Future<void> playAlbum(Album album, {bool shuffle = false}) =>
      _load(() async => (await ref.read(apiProvider).getAlbum(album.id)).tracks, shuffle: shuffle);

  /// Plays [tracks] (an album page's list) starting at [index].
  Future<void> playTracks(List<Track> tracks, {int index = 0, bool shuffle = false}) =>
      _load(() async => tracks, index: index, shuffle: shuffle);

  Future<void> addNext(List<Track> tracks) => _engine.addNext(tracks);
  Future<void> addLast(List<Track> tracks) => _engine.addLast(tracks);
  Future<void> removeAt(int index) => _engine.removeAt(index);
  Future<void> move(int from, int to) => _engine.move(from, to);

  Future<void> playPlaylist(Playlist playlist, {bool shuffle = false}) =>
      _load(() async => (await ref.read(apiProvider).getPlaylist(playlist.id)).tracks, shuffle: shuffle);

  /// All of an artist's albums, in the server's order.
  Future<void> playArtist(Artist artist, {bool shuffle = false}) => _load(() async {
        final api = ref.read(apiProvider);
        final albums = (await api.getArtist(artist.id)).albums.take(12);
        final details = await Future.wait([for (final a in albums) api.getAlbum(a.id)]);
        return [for (final d in details) ...d.tracks];
      }, shuffle: shuffle);

  /// Puts a saved session back, paused.
  Future<void> restore(SavedSession s) {
    ref.read(likedProvider.notifier).seed(s.tracks, addOnly: true);
    return _engine.restore(
      s.tracks,
      index: s.index,
      position: s.position,
      shuffled: s.shuffled,
      repeat: s.repeat,
      volume: s.volume,
    );
  }

  /// Every song in the library, shuffled (not a random handful).
  Future<void> shuffleAll() => _load(_everySong, shuffle: true);

  /// The whole library as a list: the saved or already loaded list at once, or
  /// once the pages have all arrived (a toast says so when it takes a moment).
  /// If that fails or takes more than a minute, whatever is loaded, or 50 random songs.
  Future<List<Track>> _everySong() async {
    final loaded = ref.read(libraryAllSongsProvider).value;
    if (loaded != null && loaded.complete) return loaded.songs;
    final done = Completer<List<Track>>();
    final waiting = Timer(const Duration(milliseconds: 700), () {
      if (!done.isCompleted) ref.read(toastProvider.notifier).show('Loading your whole library…');
    });
    final sub = ref.listen(libraryAllSongsProvider, (_, next) {
      if (done.isCompleted) return;
      final v = next.value;
      if (v != null && v.complete) done.complete(v.songs);
      if (next.hasError && !next.hasValue) done.completeError(next.error!);
    }, fireImmediately: true);
    try {
      return await done.future.timeout(const Duration(seconds: 60));
    } catch (_) {
      final partial = ref.read(libraryAllSongsProvider).value?.songs;
      return partial != null && partial.isNotEmpty ? partial : ref.read(apiProvider).getRandomSongs(size: 50);
    } finally {
      waiting.cancel();
      sub.close();
    }
  }

  /// Jump within the current queue.
  Future<void> playIndex(int index) => _engine.playIndex(index);

  /// Play/pause. With nothing queued there is nothing to start.
  Future<void> toggle() => state.playing ? _engine.pause() : _engine.play();

  Future<void> next() => _engine.next();

  /// Stops and forgets the queue (signing out).
  Future<void> stop() => _engine.stop();
  Future<void> previous() => _engine.previous();

  Future<void> seekFraction(double f) {
    final d = state.track?.duration ?? Duration.zero;
    return _engine.seek(Duration(microseconds: (d.inMicroseconds * f.clamp(0.0, 1.0)).round()));
  }

  Future<void> setVolume(double v) => _engine.setVolume(v);

  double? _beforeMute;

  /// Mutes, or brings the volume back to where it was. Un-muting from a volume
  /// that was dragged to zero goes to half.
  Future<void> toggleMute() {
    if (state.volume > 0) {
      _beforeMute = state.volume;
      return _engine.setVolume(0);
    }
    final back = _beforeMute;
    _beforeMute = null;
    return _engine.setVolume(back == null || back <= 0 ? .5 : back);
  }
  Future<void> toggleShuffle() => _engine.setShuffle(!state.shuffle);
  Future<void> toggleRepeat() => _engine.setRepeat(state.repeat.next);
}

final playbackProvider = NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);

/// Playback position, updated by the engine (about 30 Hz while playing).
/// A notifier so the progress bars repaint without rebuilding the tree.
final positionProvider = Provider<ValueNotifier<Duration>>((ref) {
  final engine = ref.watch(playbackEngineProvider);
  final n = ValueNotifier<Duration>(engine.position);
  final sub = engine.positions.listen((p) => n.value = p);
  ref.onDispose(() {
    sub.cancel();
    n.dispose();
  });
  return n;
});

/// The track being played, or null until something has been queued.
final currentTrackProvider = Provider<Track?>((ref) => ref.watch(playbackProvider.select((s) => s.track)));

/// Id of the playing track (changes on every skip, even within one album).
final currentTrackIdProvider = Provider<String?>((ref) => ref.watch(currentTrackProvider.select((t) => t?.id)));

/// The album that is the active one, or null before anything started.
final activeAlbumIdProvider = Provider<String?>((ref) {
  final started = ref.watch(playbackProvider.select((s) => s.started));
  return started ? ref.watch(currentTrackProvider.select((t) => t?.albumId)) : null;
});

/// Cover identity of the playing track (the scheme follows it).
final currentCoverKeyProvider = Provider<CoverKey?>((ref) {
  final track = ref.watch(currentTrackProvider);
  return track == null ? null : (albumId: track.albumId, coverArt: track.coverArt);
});


/// Ids of the tracks the person has hearted. Seeded from the `starred` flag
/// of every track list we load, and written to the server (`star`/`unstar`)
/// as it changes.
class LikedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Adopts what the server says about [tracks]. With [addOnly] (a restored,
  /// possibly stale queue) nothing is un-hearted.
  void seed(Iterable<Track> tracks, {bool addOnly = false}) {
    final next = {...state};
    for (final t in tracks) {
      if (t.starred) {
        next.add(t.id);
      } else if (!addOnly) {
        next.remove(t.id);
      }
    }
    if (next.length != state.length || !next.containsAll(state)) state = next;
  }

  /// Hearts or un-hearts right away and tells the server; if that fails the
  /// heart goes back and a message says so.
  Future<void> toggle(Track track) async {
    final was = state.contains(track.id);
    state = was ? ({...state}..remove(track.id)) : {...state, track.id};
    try {
      final api = ref.read(apiProvider);
      if (was) {
        await api.unstar(trackId: track.id);
      } else {
        await api.star(trackId: track.id);
      }
    } catch (_) {
      state = was ? {...state, track.id} : ({...state}..remove(track.id));
      ref.read(toastProvider.notifier).show('Couldn\'t update your hearts. Check your connection.', error: true);
    }
  }
}

final likedProvider = NotifierProvider<LikedNotifier, Set<String>>(LikedNotifier.new);

/// Shared visualizer model. SIMULATED (see [VisualizerSource]).
final visualizerSourceProvider = Provider<VisualizerSource>((ref) => SimulatedVisualizerSource());
