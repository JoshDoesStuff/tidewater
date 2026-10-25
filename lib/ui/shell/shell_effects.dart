import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../../app/theme/album_scheme.dart';
import '../../app/theme/motion.dart';
import '../now_playing/visualizer/visualizer.dart';
import '../widgets/shapes/morph_path.dart';
import '../widgets/shapes/morph_shape.dart';

/// Faint life behind the pages: three slowly drifting scalloped blobs, a
/// mouse spotlight, and (while playing) a fainter Aurora. Never competes with
/// text: everything is low alpha.
class AmbientLayer extends ConsumerStatefulWidget {
  const AmbientLayer({super.key, required this.pointer});

  /// Pointer position in this layer's coordinates.
  final ValueNotifier<Offset> pointer;

  @override
  ConsumerState<AmbientLayer> createState() => _AmbientLayerState();
}

class _AmbientLayerState extends ConsumerState<AmbientLayer>
    with SingleTickerProviderStateMixin {
  // Very slow drift: one full cycle every 60 s.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  bool _auroraMounted = false;

  @override
  void initState() {
    super.initState();
    _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.reduced(context);
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final npOpen = ref.watch(nowPlayingOpenProvider);
    final show = playing && !npOpen && !reduced;
    if (show) _auroraMounted = true;
    final blob = scheme.primaryContainer.withValues(alpha: .13);
    return LayoutBuilder(
      builder: (context, box) {
        final k = math.max(.6, box.maxWidth / 1280);
        Widget shape(
          double left,
          double top,
          double size,
          int lobes,
          double spin,
          double phase, {
          bool right = false,
        }) {
          final s = size * k;
          return AnimatedBuilder(
            animation: _drift,
            builder: (context, child) {
              final t = _drift.value * 2 * math.pi + phase;
              return Positioned(
                left: right
                    ? null
                    : left * k + (reduced ? 0 : math.sin(t) * 22),
                right: right ? -left * k : null,
                top: top * k + (reduced ? 0 : math.cos(t) * 16),
                child: child!,
              );
            },
            child: SizedBox.square(
              dimension: s,
              child: MorphShape(
                params: ShapeParams(lobes: lobes, amp: .09, base: .95),
                morph: 1,
                squareBase: false,
                shadow: false,
                spin: reduced ? 0 : spin,
                child: ColoredBox(color: blob),
              ),
            ),
          );
        }

        return ExcludeSemantics(
          child: IgnorePointer(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                shape(-140, 440, 520, 7, .12, 0),
                shape(100, -140, 380, 5, -.15, 2, right: true),
                shape(780, 560, 300, 9, .18, 4),
                if (_auroraMounted)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: show ? 1 : 0,
                      duration: Motion.slow,
                      onEnd: () {
                        if (!show && mounted) {
                          setState(() => _auroraMounted = false);
                        }
                      },
                      child: const Visualizer(
                        mode: VizMode.aurora,
                        intensity: .6,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _SpotPainter(widget.pointer, scheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter(this.pointer, this.color) : super(repaint: pointer);

  final ValueNotifier<Offset> pointer;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = pointer.value;
    if (c == Offset.zero) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: .11), color.withValues(alpha: 0)],
          stops: const [0, .62],
        ).createShader(Rect.fromCircle(center: c, radius: 300)),
    );
  }

  @override
  bool shouldRepaint(_SpotPainter old) => old.color != color;
}

/// Color wash that expands from the last click when the track changes.
class WashLayer extends ConsumerStatefulWidget {
  const WashLayer({super.key});

  @override
  ConsumerState<WashLayer> createState() => _WashLayerState();
}

class _WashLayerState extends ConsumerState<WashLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  Offset _origin = Offset.zero;
  Color _color = Colors.transparent;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _trigger() {
    if (Motion.reduced(context)) return;
    final box = context.findRenderObject() as RenderBox?;
    final global = ref.read(pointerOriginProvider).value;
    final size = box?.size ?? const Size(1280, 800);
    _origin = (global != null && box != null)
        ? box.globalToLocal(global)
        : size.center(Offset.zero);
    final album = ref.read(currentAlbumProvider);
    final dark = ref.read(darkThemeProvider);
    _color = AlbumScheme.of(
      album,
      dark ? Brightness.dark : Brightness.light,
    ).primary;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackProvider.select((s) => (s.index, s.started)), (
      prev,
      next,
    ) {
      if (prev != null && prev != next && next.$2) _trigger();
    });
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (!_c.isAnimating) return const SizedBox.expand();
            final t = Motion.emphasized.transform(_c.value);
            return CustomPaint(
              size: Size.infinite,
              painter: _WashPainter(
                _origin,
                _color.withValues(alpha: .5 * (1 - t)),
                900 * t,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WashPainter extends CustomPainter {
  _WashPainter(this.origin, this.color, this.radius);

  final Offset origin;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, .62],
        ).createShader(Rect.fromCircle(center: origin, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_WashPainter old) =>
      old.origin != origin || old.color != color || old.radius != radius;
}
