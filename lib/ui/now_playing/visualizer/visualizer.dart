import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../app/theme/motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/playback_providers.dart';
import '../../../app/providers/settings_providers.dart';
import '../../../core/playback/visualizer_source.dart';

/// Background visualizer: one `CustomPainter` on a throttled `Ticker`.
///
/// Levels come from [VisualizerSource], which is SIMULATED today (see its
/// docs). Colors follow the (animated) scheme. Pauses while the window is
/// hidden or minimized; the owner simply doesn't build it when Now Playing
/// is closed.
class Visualizer extends ConsumerStatefulWidget {
  const Visualizer({
    super.key,
    required this.mode,
    this.intensity = 1,
    this.ringRect,
    this.fps = 60,
    this.paused,
  });

  final VizMode mode;

  /// 1 in Now Playing, about .6 behind the pages.
  final double intensity;

  /// How often it is drawn at most: 60 in Now Playing, 30 behind the pages, where its slow
  /// drift does not need more and a big window is costly to fill.
  final int fps;

  /// While this is true no new frames are drawn (the last one stays).
  final ValueListenable<bool>? paused;

  /// Cover bounds (in this widget's coordinates) the Ring style radiates from.
  final Rect? Function()? ringRect;

  @override
  ConsumerState<Visualizer> createState() => _VisualizerState();
}

class _VizModel {
  double bass = 0; // smoothed
  double high = 0;
}

class _VisualizerState extends ConsumerState<Visualizer>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _model = _VizModel();
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastPaint = Duration.zero;
  bool _visible = true;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: one still frame instead of the drifting animation.
    _reduced = Motion.reduced(context);
    _sync();
  }

  void _sync() {
    if (_visible && !_reduced) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
      if (_reduced) {
        ref.read(visualizerSourceProvider).update(playing: ref.read(playbackProvider).playing);
        _frame.value++;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (visible == _visible) return;
    _visible = visible;
    _sync();
  }

  void _onTick(Duration elapsed) {
    if (widget.paused?.value ?? false) return;
    // Capped (60 fps even on high-refresh displays; less behind the pages).
    if ((elapsed - _lastPaint).inMicroseconds < 1000000 ~/ widget.fps - 1500) return;
    _lastPaint = elapsed;
    final playing = ref.read(playbackProvider).playing;
    ref.read(visualizerSourceProvider).update(playing: playing);
    _frame.value++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == VizMode.off) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _VizPainter(
              repaint: _frame,
              source: ref.read(visualizerSourceProvider),
              model: _model,
              mode: widget.mode,
              intensity: widget.intensity,
              ringRect: widget.ringRect,
              primary: scheme.primary,
              container: scheme.primaryContainer,
              tertiary: scheme.tertiaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  _VizPainter({
    required Listenable repaint,
    required this.source,
    required this.model,
    required this.mode,
    required this.intensity,
    required this.ringRect,
    required this.primary,
    required this.container,
    required this.tertiary,
  }) : super(repaint: repaint);

  final VisualizerSource source;
  final _VizModel model;
  final VizMode mode;
  final double intensity;
  final Rect? Function()? ringRect;
  final Color primary;
  final Color container;
  final Color tertiary;

  static const _shapes = [
    (.14, .3, 150.0, 7, .1),
    (.86, .26, 190.0, 5, .12),
    (.28, .8, 170.0, 8, .09),
    (.72, .78, 210.0, 4, .14),
    (.5, .5, 250.0, 9, .06),
    (.93, .9, 120.0, 6, .12),
    (.07, .9, 110.0, 5, .1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sx = w / 1280;
    final lvl = source.levels;
    final nb = lvl.length;
    final tt = source.phase;
    final bass = source.average(0, 8);
    final mid = source.average(8, 32);
    final hi = source.average(32, 64);
    model.bass += (bass - model.bass) * .04;
    model.high += (hi - model.high) * .04;
    final bS = model.bass;
    final hS = model.high;
    final I = intensity;

    switch (mode) {
      case VizMode.aurora:
        final blobs = [
          (.28, .35, primary, 430.0, 0.0),
          (.72, .62, container, 540.0, 2.1),
          (.5, .88, tertiary, 480.0, 4.2),
          (.84, .2, primary, 340.0, 1.3),
        ];
        for (final (i, (fx, fy, c, r, ph)) in blobs.indexed) {
          final x = w * fx + math.sin(tt * .11 + ph) * 140 * sx;
          final y = h * fy + math.cos(tt * .085 + ph) * 90 * sx;
          final radius = r * sx * (1 + bS * .4 + (i == 3 ? hS * .35 : 0));
          canvas.drawRect(
            Offset.zero & size,
            Paint()
              ..shader =
                  RadialGradient(
                    colors: [
                      c.withValues(alpha: ((.3 + bS * .3) * I).clamp(0, 1)),
                      c.withValues(alpha: 0),
                    ],
                  ).createShader(
                    Rect.fromCircle(center: Offset(x, y), radius: radius),
                  ),
          );
        }
        for (var r = 0; r < 3; r++) {
          final p = Path()..moveTo(0, h);
          for (var x = 0.0; x <= w; x += 16) {
            final y =
                h * (.86 - r * .06) -
                math.sin(x * .006 / sx + tt * (1 + r * .4) + r) *
                    (14 + mid * 56) *
                    sx -
                lvl[(x / w * (nb - 1)).floor()] * 64 * sx * (1 - r * .25);
            p.lineTo(x, y);
          }
          p
            ..lineTo(w, h)
            ..close();
          canvas.drawPath(
            p,
            Paint()
              ..color = primary.withValues(
                alpha: (.07 * I * (1 + hi * 1.5)).clamp(0, 1),
              ),
          );
        }
      case VizMode.shapes:
        for (final (i, (fx, fy, radius, lobes, amp)) in _shapes.indexed) {
          final l = lvl[(i * 9) % nb];
          final x = w * fx + math.sin(tt * .4 + i) * 40 * sx;
          final y = h * fy + math.cos(tt * .33 + i * 1.7) * 34 * sx;
          final rot = tt * .25 * (i.isOdd ? -1 : 1);
          final R = radius * sx * (1 + l * .5);
          final p = Path();
          for (var k = 0; k <= 90; k++) {
            final t = k / 90 * math.pi * 2;
            final rr = R * (1 + amp * math.cos(lobes * t + rot));
            final px = x + rr * math.cos(t);
            final py = y + rr * math.sin(t);
            k == 0 ? p.moveTo(px, py) : p.lineTo(px, py);
          }
          p.close();
          canvas.drawPath(
            p,
            Paint()
              ..color = (i.isOdd ? primary : tertiary).withValues(
                alpha: ((.05 + l * .12) * I).clamp(0, 1),
              ),
          );
        }
      case VizMode.bars:
        const n = 26;
        final bw = w / n;
        for (var i = 0; i < n; i++) {
          final hh = 22 * sx + lvl[(i * nb / n).floor()] * h * .5;
          final x = i * bw + 7 * sx;
          final rect = Rect.fromLTWH(x, h - hh, bw - 14 * sx, hh + 30 * sx);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(22 * sx)),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primary.withValues(alpha: 0),
                  primary.withValues(alpha: (.3 * I).clamp(0, 1)),
                  container.withValues(alpha: (.05 * I).clamp(0, 1)),
                ],
                stops: const [0, .05, 1],
              ).createShader(Rect.fromLTWH(x, h - hh, bw, hh)),
          );
        }
      case VizMode.ring:
        final cover = ringRect?.call();
        if (cover == null || I < 1) return;
        const rays = 96;
        final c = cover.center;
        final r0 = cover.width / 2 * .9;
        final k = cover.width / 440;
        final paint = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7 * k;
        for (var i = 0; i < rays; i++) {
          final a = i / rays * math.pi * 2 - math.pi / 2 + tt * .02;
          final m = i < rays / 2 ? i : rays - 1 - i;
          final l = lvl[(m * (nb - 1) / (rays / 2)).floor()];
          final len = (6 + l * 70) * k;
          paint.color = primary.withValues(alpha: .25 + .5 * l);
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * (r0 + 20 * k),
            c + Offset(math.cos(a), math.sin(a)) * (r0 + 20 * k + len),
            paint,
          );
        }
      case VizMode.off:
        break;
    }
  }

  @override
  bool shouldRepaint(_VizPainter old) =>
      old.mode != mode ||
      old.intensity != intensity ||
      old.primary != primary ||
      old.container != container ||
      old.tertiary != tertiary;
}
