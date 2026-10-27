import '../widgets/hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/providers/selection.dart';
import '../../app/providers/ui_providers.dart';
import '../../app/theme/motion.dart';
import '../widgets/playlist_flow.dart';

/// Appears over the page while songs are picked: how many, and what to do with
/// them all. Esc or the close button lets go of them.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    final scheme = Theme.of(context).colorScheme;
    final shown = selection.isNotEmpty;
    final scope = ref.watch(selectionScopeProvider);
    // Keeps the last picked songs on screen while the bar fades out.
    return AnimatedSlide(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.curve(context, Motion.emphasized),
      offset: shown ? Offset.zero : const Offset(0, -.6),
      child: AnimatedOpacity(
        duration: Motion.of(context, Motion.medium),
        opacity: shown ? 1 : 0,
        child: IgnorePointer(
          ignoring: !shown,
          child: Material(
            color: scheme.secondaryContainer,
            elevation: 6,
            shadowColor: scheme.shadow,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HintIconButton(
                    tooltip: 'Clear selection',
                    onPressed: ref.read(selectionProvider.notifier).clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      selection.length == 1 ? '1 selected' : '${selection.length} selected',
                      style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _Action(Icons.play_arrow_rounded, 'Play', () => _play(ref, selection)),
                  _Action(Icons.playlist_play_rounded, 'Play next', () => _next(ref, selection)),
                  _Action(Icons.queue_music_rounded, 'Add to queue', () => _queue(ref, selection)),
                  _Action(Icons.playlist_add_rounded, 'Add to playlist…', () async {
                    await addToPlaylistFlow(context, ref, selection.tracks);
                    ref.read(selectionProvider.notifier).clear();
                  }),
                  _Action(Icons.favorite_border_rounded, 'Like', () => _like(ref, selection)),
                  if (scope?.remove != null)
                    _Action(Icons.playlist_remove_rounded, scope!.removeLabel, () async {
                      final picked = selection.keys;
                      ref.read(selectionProvider.notifier).clear();
                      await scope.remove!(picked);
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _done(WidgetRef ref, String message) {
    ref.read(toastProvider.notifier).show(message);
    ref.read(selectionProvider.notifier).clear();
  }

  static Future<void> _play(WidgetRef ref, TrackSelection s) async {
    final tracks = s.tracks;
    ref.read(selectionProvider.notifier).clear();
    await ref.read(playbackProvider.notifier).playTracks(tracks);
  }

  static Future<void> _next(WidgetRef ref, TrackSelection s) async {
    await ref.read(playbackProvider.notifier).addNext(s.tracks);
    _done(ref, s.length == 1 ? 'Playing next.' : 'Playing ${s.length} songs next.');
  }

  static Future<void> _queue(WidgetRef ref, TrackSelection s) async {
    await ref.read(playbackProvider.notifier).addLast(s.tracks);
    _done(ref, s.length == 1 ? 'Added to the queue.' : 'Added ${s.length} songs to the queue.');
  }

  static Future<void> _like(WidgetRef ref, TrackSelection s) async {
    final liked = ref.read(likedProvider);
    final likes = ref.read(likedProvider.notifier);
    var n = 0;
    for (final t in s.tracks) {
      if (liked.contains(t.id)) continue;
      await likes.toggle(t);
      n++;
    }
    _done(ref, n == 0 ? 'They were all liked already.' : (n == 1 ? 'Liked 1 song.' : 'Liked $n songs.'));
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HintIconButton(tooltip: label, onPressed: onTap, icon: Icon(icon));
  }
}
