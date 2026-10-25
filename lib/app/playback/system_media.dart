/// A button pressed in the Windows media overlay, on a keyboard's media keys
/// or a headset.
enum SystemMediaButton { play, pause, next, previous, stop }

/// What the app tells the operating system about playback (the media overlay,
/// lock screen and media keys) and hears back. The real one is
/// `SmtcControls` (smtc_windows); tests and tools use [NoSystemMedia].
abstract class SystemMediaControls {
  Stream<SystemMediaButton> get buttons;

  /// The current track. [thumbnailUri] is a `file:///` or `https://` address
  /// of the cover, when known.
  Future<void> setTrack({required String title, required String artist, required String album, String? thumbnailUri});

  Future<void> setPlaying(bool playing);

  Future<void> setTimeline({required Duration position, required Duration duration});

  /// Nothing is playing any more (queue emptied, signed out).
  Future<void> clear();

  Future<void> dispose();
}

class NoSystemMedia implements SystemMediaControls {
  const NoSystemMedia();

  @override
  Stream<SystemMediaButton> get buttons => const Stream.empty();
  @override
  Future<void> setTrack({required String title, required String artist, required String album, String? thumbnailUri}) async {}
  @override
  Future<void> setPlaying(bool playing) async {}
  @override
  Future<void> setTimeline({required Duration position, required Duration duration}) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> dispose() async {}
}
