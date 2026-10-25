import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/playback/visualizer_source.dart';

/// Mutable state shared between [WavyScrubber] and its painter.
class _WavyModel {
  double amplitude = 0;
  double phase = 0;
  bool dragging = false;
}

/// Wavy progress bar bound to playback: a sine path over the played portion,
/// a flat track for the rest and a vertical pill handle. Drag (or click) to
/// scrub. The wave flattens when paused; with [breathe] its amplitude
/// follows the bass of the (simulated) visualizer.
class WavyScrubber extends ConsumerStatefulWidget {
  const WavyScrubber({
    super.key,
    this.amplitude = 3,
    this.breathe = 0,
    this.wavelength = 18,
    this.strokeWidth = 4,
    this.padding = 2,
  });

  final double amplitude;

  /// Extra amplitude per unit of average spectrum level.
  final double breathe;
  final double wavelength;
  final double strokeWidth;
  final double padding;

  @override
  ConsumerState<WavyScrubber> createState() => _WavyScrubberState();
}

class _WavyScrubberState extends ConsumerState<WavyScrubber> with SingleTickerProviderStateMixin {
  final _model = _WavyModel();
  final _frame = ValueNotifier<int>(0);
  Ticker? _ticker;
  Duration _last = Duration.zero;
  bool _playing = false;
  bool _reduced = false;

  // Smooth position: the engine reports about 30 times a second, which would
  // advance the bar in visible steps. Between reports the position is
  // extrapolated from a monotonic clock, so it glides at display rate.
  final _clock = Stopwatch()..start();
  Duration _anchorPos = Duration.zero;
  Duration _anchorAt = Duration.zero;
  ValueNotifier<Duration>? _positionSource;

  /// Best estimate of the playback position right now.
  Duration _estimate(Duration duration) {
    var p = _anchorPos;
    if (_playing && !_model.dragging) p += _clock.elapsed - _anchorAt;
    if (p < Duration.zero) return Duration.zero;
    return p > duration ? duration : p;
  }

  void _onPosition() {
    final actual = _positionSource!.value;
    final now = _clock.elapsed;
    final shown = _playing ? _anchorPos + (now - _anchorAt) : _anchorPos;
    // A report that lags slightly behind what is already shown must not pull
    // the bar backwards; real seeks (large jumps) are taken as they come.
    final lagging = _playing && actual < shown && shown - actual < const Duration(milliseconds: 300);
    _anchorPos = lagging ? shown : actual;
    _anchorAt = now;
    if (!_playing) _frame.value++;
  }

  @override
  void initState() {
    super.initState();
    final source = ref.read(positionProvider);
    _positionSource = source;
    _anchorPos = source.value;
    source.addListener(_onPosition);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    _sync();
  }

  double _target(VisualizerSource source) =>
      _playing ? widget.amplitude + widget.breathe * source.average(0, VisualizerSource.bands) : 0;

  void _sync() {
    final source = ref.read(visualizerSourceProvider);
    if (_reduced) {
      _ticker?.stop();
      _model.amplitude = _playing ? widget.amplitude : 0;
      _frame.value++;
      return;
    }
    final needed = _playing || _model.amplitude > .02;
    if (needed && _ticker == null) {
      _last = Duration.zero;
      _ticker = createTicker(_onTick)..start();
    } else if (needed && !_ticker!.isActive) {
      _last = Duration.zero;
      _ticker!.start();
    }
    _model.amplitude = _model.amplitude.clamp(0, widget.amplitude + widget.breathe * 2);
    // Settle if the target is already reached.
    if (!needed) {
      _model.amplitude = _target(source);
      _frame.value++;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = math.min(.1, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    final source = ref.read(visualizerSourceProvider);
    source.update(playing: _playing);
    final k = 1 - math.pow(1 - .1, dt * 60).toDouble();
    _model.amplitude += (_target(source) - _model.amplitude) * k;
    if (_playing) _model.phase += 8.1 * dt;
    _frame.value++;
    if (!_playing && _model.amplitude < .02) {
      _model.amplitude = 0;
      _ticker?.stop();
    }
  }

  void _seek(double dx) {
    final w = context.size?.width ?? 1;
    ref.read(playbackProvider.notifier).seekFraction((dx / w).clamp(0.0, 1.0));
  }

  void _setDragging(bool v) {
    _model.dragging = v;
    _frame.value++;
  }

  @override
  void dispose() {
    _positionSource?.removeListener(_onPosition);
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = ref.watch(currentTrackProvider.select((t) => t?.duration)) ?? Duration.zero;
    final position = ref.watch(positionProvider);
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    if (playing != _playing) {
      // Freeze or resume the extrapolation from exactly where the bar is.
      _anchorPos = _estimate(duration);
      _anchorAt = _clock.elapsed;
      _playing = playing;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _seek(d.localPosition.dx),
        onHorizontalDragStart: (d) {
          _setDragging(true);
          _seek(d.localPosition.dx);
        },
        onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx),
        onHorizontalDragEnd: (_) => _setDragging(false),
        onHorizontalDragCancel: () => _setDragging(false),
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: WavyPainter(
              repaint: Listenable.merge([position, _frame]),
              fraction: () =>
                  duration.inMicroseconds == 0 ? 0 : _estimate(duration).inMicroseconds / duration.inMicroseconds,
              amplitude: () => _model.amplitude,
              phase: () => _model.phase,
              dragging: () => _model.dragging,
              wavelength: widget.wavelength,
              strokeWidth: widget.strokeWidth,
              padding: widget.padding,
              played: scheme.primary,
              track: scheme.secondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// The played part of the squiggle: a sine from [start] to [end].
///
/// Sampled about 20 times per wavelength so it reads as a smooth curve, and
/// the last point is always exactly [end], so as the playhead moves the wave
/// grows continuously rather than in sampling-step jumps.
Path wavePath({
  required double start,
  required double end,
  required double centerY,
  required double amplitude,
  required double wavelength,
  required double phase,
}) {
  double y(double x) => centerY + amplitude * math.sin(2 * math.pi * (x - start) / wavelength - phase);
  final step = (wavelength / 20).clamp(.75, 2.0);
  final path = Path()..moveTo(start, y(start));
  for (var x = start + step; x < end; x += step) {
    path.lineTo(x, y(x));
  }
  if (end > start) path.lineTo(end, y(end));
  return path;
}

class WavyPainter extends CustomPainter {
  WavyPainter({
    required Listenable repaint,
    required this.fraction,
    required this.amplitude,
    required this.phase,
    required this.dragging,
    required this.wavelength,
    required this.strokeWidth,
    required this.padding,
    required this.played,
    required this.track,
  }) : super(repaint: repaint);

  final double Function() fraction;
  final double Function() amplitude;
  final double Function() phase;
  final bool Function() dragging;
  final double wavelength;
  final double strokeWidth;
  final double padding;
  final Color played;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final x0 = padding;
    final x1 = size.width - padding;
    final cy = size.height / 2;
    final xp = x0 + (x1 - x0) * fraction();
    final amp = amplitude();
    final ph = phase();

    // Played portion: a sine path that always ends exactly 6 px before the
    // handle. Sampled finely (about 20 points per wavelength) so it reads as a
    // smooth curve, and the final point is explicit so the length grows
    // continuously instead of in sampling-step jumps.
    final wave = wavePath(
      start: x0,
      end: math.max(x0, xp - 6),
      centerY: cy,
      amplitude: amp,
      wavelength: wavelength,
      phase: ph,
    );
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = played,
    );

    // Handle grows while dragging.
    final hw = dragging() ? 2.5 : 4.0;
    final hh = math.min(13.0, size.height * .32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(xp - hw / 2, cy - hh, hw, hh * 2), Radius.circular(hw / 2)),
      Paint()..color = played,
    );

    // Remaining track and end dot.
    final trackLeft = xp + strokeWidth * 1.3;
    if (x1 > trackLeft) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(trackLeft, cy - strokeWidth / 2, x1, cy + strokeWidth / 2),
          Radius.circular(strokeWidth / 2),
        ),
        Paint()..color = track,
      );
    }
    canvas.drawCircle(Offset(x1 - 3, cy), 2, Paint()..color = played);
  }

  @override
  bool shouldRepaint(WavyPainter old) =>
      old.wavelength != wavelength ||
      old.strokeWidth != strokeWidth ||
      old.padding != padding ||
      old.played != played ||
      old.track != track;
}
