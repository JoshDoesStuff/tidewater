import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/lyrics/lyrics.dart';
import '../../core/lyrics/placeholder_lyrics.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../../core/models/track.dart';
import '../../core/playback/playback_engine.dart';
import '../../core/playback/simulated_engine.dart';
import '../../core/playback/visualizer_source.dart';
import 'cover_providers.dart';
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
      await _engine.playQueue(queue, index: index, shuffle: shuffle);
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
  Future<void> playArtist(Artist artist) => _load(() async {
        final api = ref.read(apiProvider);
        final albums = (await api.getArtist(artist.id)).albums.take(12);
        final details = await Future.wait([for (final a in albums) api.getAlbum(a.id)]);
        return [for (final d in details) ...d.tracks];
      });

  Future<void> shuffleAll() => _load(() => ref.read(apiProvider).getRandomSongs(size: 50));

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

/// STAND-IN: the same lyrics for every track (real lyrics in M3).
final lyricsProvider = Provider<Lyrics>((ref) => placeholderLyrics);

class LikedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String trackId) =>
      state = state.contains(trackId) ? ({...state}..remove(trackId)) : {...state, trackId};
}

final likedProvider = NotifierProvider<LikedNotifier, Set<String>>(LikedNotifier.new);

/// Shared visualizer model. SIMULATED (see [VisualizerSource]).
final visualizerSourceProvider = Provider<VisualizerSource>((ref) => SimulatedVisualizerSource());
