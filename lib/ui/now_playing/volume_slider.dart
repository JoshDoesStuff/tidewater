import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/theme/motion.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/pressable.dart';

/// Volume: pill track with a gap-less filled part and a separate vertical
/// handle that grows on hover and narrows/lengthens while dragging, tick dots
/// at 25/50/75 %, a value bubble above the handle, a springy fill, and a
/// speaker icon that swaps loud/quiet/muted with a small bump.
class VolumeSlider extends ConsumerStatefulWidget {
  const VolumeSlider({super.key});

  @override
  ConsumerState<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends ConsumerState<VolumeSlider> with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  bool _hover = false;
  bool _drag = false;
  _Level? _level;

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  void _set(double dx, double width) {
    ref.read(playbackProvider.notifier).setVolume((dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = ref.watch(playbackProvider.select((s) => s.volume));
    final level = v == 0 ? _Level.muted : v < .4 ? _Level.quiet : _Level.loud;
    if (_level != level) {
      if (_level != null && !Motion.reduced(context)) _bump.forward(from: 0);
      _level = level;
    }
    final reduced = Motion.reduced(context);
    final active = _hover || _drag;
    return Row(
      children: [
        Tooltip(
          message: v == 0 ? 'Unmute (M)' : 'Mute (M)',
          child: Pressable(
            onTap: () => ref.read(playbackProvider.notifier).toggleMute(),
            semanticLabel: v == 0 ? 'Unmute' : 'Mute',
            builder: (context, s) => SizedBox.square(
              dimension: 36,
              child: Center(
                child: AnimatedBuilder(
                  animation: _bump,
                  builder: (context, child) => Transform.scale(
                    scale: (s.hovered ? 1.12 : 1) * (1 + .3 * (_bump.value < .4 ? _bump.value / .4 : 1 - (_bump.value - .4) / .6)),
                    child: child,
                  ),
                  child: VolumeGlyph(level: level.index, color: scheme.primary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        const SizedBox(width: 14),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    setState(() => _drag = true);
                    _set(e.localPosition.dx, w);
                  },
                  onPointerMove: (e) {
                    if (_drag) _set(e.localPosition.dx, w);
                  },
                  onPointerUp: (_) => setState(() => _drag = false),
                  onPointerCancel: (_) => setState(() => _drag = false),
                  child: SizedBox(
                    height: 32,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: v),
                      duration: _drag || reduced ? Duration.zero : const Duration(milliseconds: 350),
                      curve: Motion.spring,
                      builder: (context, shown, _) {
                        final x = shown * w;
                        final handleW = _drag ? 4.0 : (_hover ? 8.0 : 6.0);
                        final handleH = _drag ? 38.0 : 32.0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 4,
                              bottom: 4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer.withValues(alpha: .7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 4,
                              bottom: 4,
                              width: (x - 4).clamp(0.0, w),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(12),
                                    right: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            for (final p in const [.25, .5, .75])
                              Positioned(
                                left: p * w - 1.5,
                                top: 14.5,
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: scheme.onSurfaceVariant.withValues(alpha: .5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            AnimatedPositioned(
                              duration: Motion.of(context, Motion.fast),
                              curve: Motion.spring,
                              left: x - handleW / 2,
                              top: (32 - handleH) / 2,
                              width: handleW,
                              height: handleH,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            Positioned(
                              left: x,
                              bottom: 46,
                              child: FractionalTranslation(
                                translation: const Offset(-.5, 0),
                                child: AnimatedOpacity(
                                  opacity: active ? 1 : 0,
                                  duration: Motion.of(context, Motion.fast),
                                  child: AnimatedScale(
                                    scale: active ? 1 : .6,
                                    duration: Motion.of(context, Motion.medium),
                                    curve: Motion.spring,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${(v * 100).round()}',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: scheme.onPrimary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Speaker states; the index is the [VolumeGlyph] level (0 loud, 2 muted).
enum _Level { loud, quiet, muted }
