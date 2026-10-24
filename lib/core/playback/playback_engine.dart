import '../models/track.dart';

/// Immutable snapshot of the player.
class PlaybackState {
  const PlaybackState({
    required this.queue,
    this.index = 0,
    this.started = false,
    this.playing = false,
    this.volume = .7,
    this.shuffle = false,
    this.repeat = false,
  });

  final List<Track> queue;
  final int index;

  /// False until something has actually been played; the UI still shows
  /// the first track as a resting state.
  final bool started;
  final bool playing;
  final double volume;
  final bool shuffle;
  final bool repeat;

  Track get track => queue[index];

  PlaybackState copyWith({
    int? index,
    bool? started,
    bool? playing,
    double? volume,
    bool? shuffle,
    bool? repeat,
  }) =>
      PlaybackState(
        queue: queue,
        index: index ?? this.index,
        started: started ?? this.started,
        playing: playing ?? this.playing,
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

  Future<void> playIndex(int index);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> setVolume(double volume);
  Future<void> setShuffle(bool value);
  Future<void> setRepeat(bool value);

  Future<void> dispose();
}
