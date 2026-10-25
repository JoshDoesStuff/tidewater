import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../playback/system_media.dart';
import 'cover_providers.dart';
import 'playback_providers.dart';

/// The operating system's media controls. `main()` swaps in the real Windows
/// one; everything else (tests, tools) gets one that does nothing.
final systemMediaProvider = Provider<SystemMediaControls>((ref) => const NoSystemMedia());

/// Keeps the Windows media overlay in step with playback (what is playing,
/// paused or not, how far along) and obeys its buttons and the keyboard's
/// media keys. Watch it once from the shell.
final systemMediaServiceProvider = Provider<void>((ref) {
  final media = ref.watch(systemMediaProvider);
  final player = ref.read(playbackProvider.notifier);
  final position = ref.watch(positionProvider);

  final sub = media.buttons.listen((b) {
    switch (b) {
      case SystemMediaButton.play:
        if (!ref.read(playbackProvider).playing) player.toggle();
      case SystemMediaButton.pause:
        if (ref.read(playbackProvider).playing) player.toggle();
      case SystemMediaButton.next:
        player.next();
      case SystemMediaButton.previous:
        player.previous();
      case SystemMediaButton.stop:
        if (ref.read(playbackProvider).playing) player.toggle();
    }
  });

  // Windows keeps counting by itself while playing, so the timeline only
  // needs telling when something other than time passing moved it.
  void sendTimeline() {
    final track = ref.read(playbackProvider).track;
    if (track == null) return;
    unawaited(media.setTimeline(position: position.value, duration: track.duration));
  }

  var previous = position.value;
  void onPosition() {
    final p = position.value;
    final step = p - previous;
    previous = p;
    if (step < Duration.zero || step > const Duration(milliseconds: 1500)) sendTimeline();
  }

  ref.listen(currentTrackProvider, (prev, track) {
    if (track == null) {
      unawaited(media.clear());
      return;
    }
    unawaited(media.setTrack(title: track.title, artist: track.artist, album: track.albumTitle));
    unawaited(media.setPlaying(ref.read(playbackProvider).playing));
    sendTimeline();
    // The cover arrives a moment later (it may need downloading).
    final art = track.coverArt;
    if (art != null) {
      unawaited(() async {
        final path = await ref.read(coverCacheProvider).localPath(art);
        if (path == null || ref.read(currentTrackProvider)?.id != track.id) return;
        await media.setTrack(
          title: track.title,
          artist: track.artist,
          album: track.albumTitle,
          thumbnailUri: Uri.file(path).toString(),
        );
      }());
    }
  }, fireImmediately: true);

  ref.listen(playbackProvider.select((s) => s.playing), (_, playing) {
    unawaited(media.setPlaying(playing));
    sendTimeline();
  });

  position.addListener(onPosition);

  ref.onDispose(() {
    position.removeListener(onPosition);
    sub.cancel();
  });
});
