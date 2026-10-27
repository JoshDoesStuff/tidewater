import '../../app/perf_flags.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/cover_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../../app/theme/album_scheme.dart';
import '../../app/theme/motion.dart';
import '../now_playing/visualizer/visualizer.dart';
import '../widgets/shapes/morph_path.dart';
import '../widgets/shapes/morph_shape.dart';
import '../widgets/smooth_scroll.dart' show pageScrolling;

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

class _AmbientLayerState extends ConsumerState<AmbientLayer> {
  // Very slow drift: one full cycle every 60 s. Driven by a timer at about 25 frames a
  // second, not by an animation: on a 144 or 180 Hz screen an animation made the whole window
  // be drawn again 180 times a second, for a drift nobody can see move that fast.
  final _drift = _Drift();
  bool _auroraMounted = false;

  @override
  void initState() {
    super.initState();
    _drift.repeat();
    pageScrolling.addListener(_onPageScrolling);
    PerfFlags.instance.addListener(_onFlags);
  }

  void _onFlags() {
    if (mounted) setState(() {});
  }

  /// The drift holds still while a page scrolls, and once it has gone on for a moment the whole
  /// background is left undrawn until it stops (it is faint, and at full screen it was drawn
  /// again under every frame of the scroll).
  bool _away = false;
  Timer? _awayTimer;

  void _onPageScrolling() {
    _awayTimer?.cancel();
    if (pageScrolling.value) {
      _drift.stop(canceled: false);
      _awayTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _away = true);
      });
    } else {
      if (!_drift.isAnimating) _drift.repeat();
      _awayTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted && _away) setState(() => _away = false);
      });
    }
  }

  @override
  void dispose() {
    _awayTimer?.cancel();
    pageScrolling.removeListener(_onPageScrolling);
    PerfFlags.instance.removeListener(_onFlags);
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.reduced(context);
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final npOpen = ref.watch(nowPlayingOpenProvider);
    final flags = PerfFlags.instance;
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
          // Drawn once and then only moved and turned by the compositor: a blob that is
          // re-clipped and repainted on every frame, at up to a thousand pixels wide, was
          // a steady cost on big windows.
          return Positioned(
            left: right ? null : left * k,
            right: right ? -left * k : null,
            top: top * k,
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, child) {
                final t = _drift.value * 2 * math.pi + phase;
                // A whole number of turns per 60 s cycle, so it does not jump when the cycle restarts.
                final turns =
                    math.max(1, (spin.abs() * 60 / (2 * math.pi)).round()) *
                    (spin < 0 ? -1 : 1);
                return Transform.translate(
                  offset: reduced
                      ? Offset.zero
                      : Offset(math.sin(t) * 22, math.cos(t) * 16),
                  child: Transform.rotate(
                    angle: reduced ? 0 : turns * 2 * math.pi * _drift.value,
                    child: child,
                  ),
                );
              },
              child: RepaintBoundary(
                child: SizedBox.square(
                  dimension: s,
                  child: MorphShape(
                    params: ShapeParams(lobes: lobes, amp: .09, base: .95),
                    morph: 1,
                    squareBase: false,
                    shadow: false,
                    child: ColoredBox(color: blob),
                  ),
                ),
              ),
            ),
          );
        }

        return ExcludeSemantics(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _away ? 0 : 1,
              duration: Motion.of(context, _away ? Motion.medium : Motion.slow),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (flags.ambient) ...[
                    shape(-140, 440, 520, 7, .12, 0),
                    shape(100, -140, 380, 5, -.15, 2, right: true),
                    shape(780, 560, 300, 9, .18, 4),
                  ],
                  if (_auroraMounted && flags.aurora)
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: show ? 1 : 0,
                        duration: Motion.slow,
                        onEnd: () {
                          if (!show && mounted) {
                            setState(() => _auroraMounted = false);
                          }
                        },
                        child: Visualizer(
                          mode: VizMode.aurora,
                          intensity: .6,
                          fps: 30,
                          paused: pageScrolling,
                        ),
                      ),
                    ),
                  // The spotlight is one small picture, drawn once and moved by the compositor as the
                  // pointer moves. (It used to be a gradient over the whole window, repainted on every
                  // pointer event: on a big window that alone made moving the mouse lag.)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: ValueListenableBuilder<Offset>(
                      valueListenable: widget.pointer,
                      builder: (context, p, child) => Transform.translate(
                        offset: p == Offset.zero
                            ? const Offset(-4000, -4000)
                            : p -
                                  const Offset(
                                    _SpotPainter.radius,
                                    _SpotPainter.radius,
                                  ),
                        child: child,
                      ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: const Size.square(_SpotPainter.radius * 2),
                          painter: _SpotPainter(scheme.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter(this.color);

  static const radius = 300.0;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const rect = Rect.fromLTWH(0, 0, radius * 2, radius * 2);
    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: .11), color.withValues(alpha: 0)],
          stops: const [0, .62],
        ).createShader(Rect.fromCircle(center: rect.center, radius: radius)),
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

  Future<void> _trigger() async {
    if (Motion.reduced(context)) return;
    final box = context.findRenderObject() as RenderBox?;
    final global = ref.read(pointerOriginProvider).value;
    final size = box?.size ?? const Size(1280, 800);
    _origin = (global != null && box != null)
        ? box.globalToLocal(global)
        : size.center(Offset.zero);
    final key = ref.read(currentCoverKeyProvider);
    if (key == null) return;
    // The new cover's colors are usually ready (the grid just showed it).
    final seed = await ref.read(coverSeedProvider(key).future);
    if (!mounted) return;
    final dark = ref.read(darkThemeProvider);
    _color = AlbumScheme.of(
      seed,
      dark ? Brightness.dark : Brightness.light,
    ).primary;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentTrackIdProvider, (prev, next) {
      // No wash for a session restored at launch (paused, nothing before it).
      final restored = prev == null && !ref.read(playbackProvider).playing;
      if (next != null && prev != next && !restored) _trigger();
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

/// A 0..1 value that goes round once every 60 seconds, updated 25 times a second.
class _Drift extends ChangeNotifier {
  final _clock = Stopwatch();
  Timer? _timer;
  double _base = 0;

  double get value => (_base + _clock.elapsedMicroseconds / 60e6) % 1;
  bool get isAnimating => _timer != null;

  void repeat() {
    if (_timer != null) return;
    _clock
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) => notifyListeners());
  }

  void stop({bool canceled = false}) {
    if (_timer == null) return;
    _base = value;
    _clock.stop();
    _timer!.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
