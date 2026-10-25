import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../../app/theme/motion.dart';
import '../widgets/art_tile.dart';
import '../widgets/effects/ripple.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import '../widgets/shapes/morph_path.dart';
import '../widgets/wavy_progress.dart';
import 'shell_keys.dart';

/// Floating pill at the bottom of the window: cover, title, transport,
/// wavy progress and time. Clicking it opens Now Playing.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final album = ref.watch(currentAlbumProvider);
    final track = ref.watch(currentTrackProvider);
    final index = ref.watch(playbackProvider.select((s) => s.index));
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final controller = ref.read(playbackProvider.notifier);
    final position = ref.watch(positionProvider);
    final reduced = Motion.reduced(context);

    return Pressable(
      onTap: () => ref.read(nowPlayingOpenProvider.notifier).set(true),
      semanticLabel: 'Open now playing: ${track.title}',
      builder: (context, s) {
        return AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.curve(context, Motion.spring),
          height: 72,
          padding: const EdgeInsets.only(left: 10, right: 24),
          transform: Matrix4.translationValues(0, s.hovered ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(color: scheme.shadow.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final showProgress = box.maxWidth >= 600;
              return Row(
                children: [
                  SizedBox.square(
                    key: miniCoverKey,
                    dimension: 52,
                    child: ArtTile(
                      album: album,
                      size: 52,
                      params: ShapeKind.forIndex(index).params.copyWith(amp: .07),
                      morph: playing ? 1 : 0,
                      spin: playing && !reduced ? .6 : 0,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 168),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(fontSize: 12.5, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ExpressiveIconButton(
                    icon: Icons.skip_previous_rounded,
                    tone: ButtonTone.ghost,
                    size: 40,
                    iconSize: 22,
                    tooltip: 'Previous',
                    onPressed: controller.previous,
                  ),
                  const SizedBox(width: 10),
                  _PlayButton(playing: playing, onTap: controller.toggle),
                  const SizedBox(width: 10),
                  ExpressiveIconButton(
                    icon: Icons.skip_next_rounded,
                    tone: ButtonTone.ghost,
                    size: 40,
                    iconSize: 22,
                    tooltip: 'Next',
                    onPressed: controller.next,
                  ),
                  if (showProgress) ...[
                    const SizedBox(width: 24),
                    const Expanded(
                      child: Align(
                        child: SizedBox(width: 170, height: 30, child: WavyScrubber()),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 34,
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: position,
                        builder: (context, p, _) => Text(
                          formatDuration(p),
                          style: text.bodySmall?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Primary play/pause: the icon rotates and scales between glyphs and the
/// corner radius morphs (round paused, squarer playing).
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: playing ? 'Pause' : 'Play',
      builder: (context, s) {
        return AnimatedScale(
          scale: s.pressed ? .92 : 1,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.curve(context, Motion.spring),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.slow),
            curve: Motion.curve(context, Motion.spring),
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(playing || s.pressed ? 16 : 24),
            ),
            child: Ripple(
              color: scheme.onPrimary,
              child: Center(child: PlayPauseIcon(playing: playing, size: 24, color: scheme.onPrimary)),
            ),
          ),
        );
      },
    );
  }
}
