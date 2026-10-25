import '../models/track.dart';
import 'play_queue.dart';

export 'play_queue.dart' show LoopMode;

/// Immutable snapshot of the player.
class PlaybackState {
  const PlaybackState({
    this.queue = const [],
    this.index = 0,
    this.started = false,
    this.playing = false,
    this.buffering = false,
    this.volume = .7,
    this.shuffle = false,
    this.repeat = LoopMode.off,
  });

  /// The tracks in the order they will play (already shuffled when [shuffle]).
  final List<Track> queue;
  final int index;

  /// False until something has actually been played.
  final bool started;
  final bool playing;

  /// Waiting for the network or the decoder.
  final bool buffering;
  final double volume;
  final bool shuffle;
  final LoopMode repeat;

  /// The current track, or null while nothing has been queued.
  Track? get track => index >= 0 && index < queue.length ? queue[index] : null;

  PlaybackState copyWith({
    List<Track>? queue,
    int? index,
    bool? started,
    bool? playing,
    bool? buffering,
    double? volume,
    bool? shuffle,
    LoopMode? repeat,
  }) =>
      PlaybackState(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        started: started ?? this.started,
        playing: playing ?? this.playing,
        buffering: buffering ?? this.buffering,
        volume: volume ?? this.volume,
        shuffle: shuffle ?? this.shuffle,
        repeat: repeat ?? this.repeat,
      );
}

/// Everything the UI may ask of playback. media_kit types never leak past
/// implementations of this interface.
abstract class PlaybackEngine {
  PlaybackState get state;
  Stream<PlaybackState> get states;

  Duration get position;

  /// Emits while playing, and on every seek or track change.
  Stream<Duration> get positions;

  /// Things worth telling the person (a track that would not play).
  Stream<String> get errors;

  /// Replaces the queue and starts playing at [index].
  Future<void> playQueue(List<Track> queue, {int index = 0, bool shuffle = false});

  /// Loads a queue without playing it (restoring the last session).
  Future<void> restore(List<Track> queue, {int index = 0, Duration position = Duration.zero});

  /// Jumps to a track already in the queue.
  Future<void> playIndex(int index);

  Future<void> addNext(List<Track> tracks);
  Future<void> addLast(List<Track> tracks);
  Future<void> removeAt(int index);
  Future<void> move(int from, int to);

  Future<void> play();
  Future<void> pause();

  /// Stops and empties the queue (signing out).
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> setVolume(double volume);
  Future<void> setShuffle(bool value);
  Future<void> setRepeat(LoopMode value);

  Future<void> dispose();
}
