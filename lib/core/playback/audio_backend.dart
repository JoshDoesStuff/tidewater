import '../models/track.dart';

/// The thing that actually makes sound (libmpv via media_kit in the app, a
/// clock in tests). It plays a short *window* of tracks, the current one and
/// the one after it, so the next track is already loaded when the current
/// ends (gapless). The queue itself, shuffle and repeat live in
/// `QueueEngine`; a backend knows nothing about them.
abstract class AudioBackend {
  Stream<bool> get playing;

  /// Playback position of the current track, roughly 10-30 times a second
  /// while playing.
  Stream<Duration> get position;

  /// Emitted when playback moves on to another item of the window by itself
  /// (the first track ended and the second began): the new window index.
  /// Never emitted for changes the engine asked for.
  Stream<int> get advanced;

  /// The last item of the window ended.
  Stream<void> get completed;

  Stream<bool> get buffering;

  /// Something went wrong playing the current track (message for people).
  Stream<String> get errors;

  Duration get currentPosition;

  /// Replaces the window and starts it (or leaves it paused) at [start].
  Future<void> open(List<Track> window, {Duration start = Duration.zero, bool play = true});

  /// Makes [track] the item after the current one (or none), replacing what
  /// was queued there.
  Future<void> setNext(Track? track);

  /// The first item finished and the second is now playing: drop the first
  /// so the window is [current, ...] again. Emits nothing.
  Future<void> dropFirst();

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// 0..1.
  Future<void> setVolume(double volume);

  Future<void> dispose();
}
