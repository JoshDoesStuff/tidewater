import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';
import '../../ui/widgets/cover_art.dart';
import 'cover_providers.dart';
import 'playback_providers.dart';

/// Loads and decodes the covers Now Playing is about to need (the playing
/// track's at full size, the next two) so opening it, or skipping, never waits
/// on a first-time decode (measured at 100+ ms hitches on real covers).
/// Watch it once from the shell.
final coverPrefetchProvider = Provider<void>((ref) {
  final held = <ImageStream, ImageStreamListener>{};

  void warm(Track t) {
    final art = t.coverArt;
    if (art == null) return;
    final store = ref.read(coverCacheProvider);
    for (final size in const [300, 800]) {
      final stream = CoverImage(store, art, size).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      // Decoded and in the image cache (or failed): done, and out of the map.
      void done() {
        stream.removeListener(listener);
        held.remove(stream);
      }

      listener = ImageStreamListener((_, _) => done(), onError: (_, _) => done());
      held[stream] = listener;
      stream.addListener(listener);
    }
  }

  void prefetch() {
    final s = ref.read(playbackProvider);
    if (s.queue.isEmpty) return;
    for (var i = s.index; i <= s.index + 2 && i < s.queue.length; i++) {
      warm(s.queue[i]);
    }
  }

  ref.listen(currentTrackIdProvider, (_, _) => prefetch(), fireImmediately: true);

  ref.onDispose(() {
    held.forEach((stream, listener) => stream.removeListener(listener));
    held.clear();
  });
});
