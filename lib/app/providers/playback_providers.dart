import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/fake_library.dart';
import '../../core/lyrics/lyrics.dart';
import '../../core/models/album.dart';
import '../../core/models/track.dart';
import '../../core/playback/playback_engine.dart';
import '../../core/playback/simulated_engine.dart';
import '../../core/playback/visualizer_source.dart';

/// The engine behind the UI. A simulated one until real playback lands.
final playbackEngineProvider = Provider<PlaybackEngine>((ref) {
  final engine = SimulatedEngine(fakeTracks);
  ref.onDispose(engine.dispose);
  return engine;
});

class PlaybackController extends Notifier<PlaybackState> {
  PlaybackEngine get _engine => ref.read(playbackEngineProvider);

  @override
  PlaybackState build() {
    final engine = ref.watch(playbackEngineProvider);
    final sub = engine.states.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return engine.state;
  }

  Future<void> playIndex(int index) => _engine.playIndex(index);

  /// Play/pause. The first press with nothing started plays the shown track.
  Future<void> toggle() => state.playing ? _engine.pause() : _engine.play();

  Future<void> next() => _engine.next();
  Future<void> previous() => _engine.previous();

  Future<void> shuffleAll() => _engine.playIndex(_random.nextInt(state.queue.length));

  final _random = math.Random();

  Future<void> seekFraction(double f) {
    final d = state.track.duration;
    return _engine.seek(Duration(microseconds: (d.inMicroseconds * f.clamp(0.0, 1.0)).round()));
  }

  Future<void> setVolume(double v) => _engine.setVolume(v);
  Future<void> toggleShuffle() => _engine.setShuffle(!state.shuffle);
  Future<void> toggleRepeat() => _engine.setRepeat(!state.repeat);
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

/// The track whose album is shown (the resting first track until started).
final currentTrackProvider = Provider<Track>((ref) => ref.watch(playbackProvider.select((s) => s.track)));

final currentAlbumProvider = Provider<Album>((ref) {
  final albumId = ref.watch(currentTrackProvider).albumId;
  return fakeAlbums.firstWhere((a) => a.id == albumId);
});

/// Index of the album that is the active one, or -1 before anything started.
final activeAlbumIndexProvider = Provider<int>((ref) {
  final started = ref.watch(playbackProvider.select((s) => s.started));
  return started ? ref.watch(playbackProvider.select((s) => s.index)) : -1;
});

final lyricsProvider = Provider<Lyrics>((ref) => fakeLyrics);

class LikedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String trackId) =>
      state = state.contains(trackId) ? ({...state}..remove(trackId)) : {...state, trackId};
}

final likedProvider = NotifierProvider<LikedNotifier, Set<String>>(LikedNotifier.new);

/// Shared visualizer model. SIMULATED (see [VisualizerSource]).
final visualizerSourceProvider = Provider<VisualizerSource>((ref) => SimulatedVisualizerSource());
