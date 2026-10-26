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

  /// Waiting for the track to start: the bar shows a squiggle sweeping along it.
  bool buffering = false;

  /// 0 to 1, how far the sweep has travelled.
  double sweep = 0;
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
  bool _buffering = false;
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
    if (_playing && !_buffering && !_model.dragging) p += _clock.elapsed - _anchorAt;
    if (p < Duration.zero) return Duration.zero;
    return p > duration ? duration : p;
  }

  void _onPosition() {
    final actual = _positionSource!.value;
    final now = _clock.elapsed;
    final shown = _playing && !_buffering ? _anchorPos + (now - _anchorAt) : _anchorPos;
    // A report that lags slightly behind what is already shown must not pull
    // the bar backwards; real seeks (large jumps) are taken as they come.
    final lagging = _playing && !_buffering && actual < shown && shown - actual < const Duration(milliseconds: 300);
    _anchorPos = lagging ? shown : actual;
    _anchorAt = now;
    if (!_playing || _buffering) _frame.value++;
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
    final needed = _playing || _buffering || _model.amplitude > .02;
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
    if (_buffering) _model.sweep = (_model.sweep + dt / 1.15) % 1;
    _frame.value++;
    if (!_playing && !_buffering && _model.amplitude < .02) {
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
    final buffering = ref.watch(playbackProvider.select((s) => s.buffering));
    if (buffering != _buffering) {
      // Hold the bar where it is while waiting, and let go when sound starts.
      _anchorPos = _estimate(duration);
      _anchorAt = _clock.elapsed;
      _buffering = buffering;
      _model.buffering = buffering;
      _model.sweep = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
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
              buffering: () => _model.buffering,
              sweep: () => _reduced ? .5 : _model.sweep,
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
    required this.buffering,
    required this.sweep,
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
  final bool Function() buffering;
  final double Function() sweep;
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
    if (buffering()) {
      _paintBuffering(canvas, x0, x1, cy, size.height);
      return;
    }
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

  /// Waiting for sound: a flat track with a squiggle that sweeps along it, in
  /// place of the played wave, so the bar never runs ahead of the audio.
  void _paintBuffering(Canvas canvas, double x0, double x1, double cy, double height) {
    // No handle while waiting. The squiggle replaces the track where it is:
    // the flat bar is drawn only to each side of it, so no gray shows behind.
    final s = sweep();
    final span = math.max(60.0, (x1 - x0) * .38);
    final centerX = x0 - span / 2 + (x1 - x0 + span) * s;
    final from = math.max(x0, centerX - span / 2);
    final to = math.min(x1, centerX + span / 2);
    final r = Radius.circular(strokeWidth / 2);
    final bar = Paint()..color = track;
    final left = math.min(from, x1);
    final right = math.max(to, x0);
    if (left > x0) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x0, cy - strokeWidth / 2, left, cy + strokeWidth / 2), r), bar);
    if (x1 > right) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(right, cy - strokeWidth / 2, x1, cy + strokeWidth / 2), r), bar);
    if (to <= from) return;
    final path = Path();
    for (var x = from; x <= to; x += 1.5) {
      final u = ((x - (centerX - span / 2)) / span).clamp(0.0, 1.0);
      final y = cy + 4 * math.sin(math.pi * u) * math.sin(2 * math.pi * (x / wavelength - s * 3));
      x == from ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = played,
    );
  }

  @override
  bool shouldRepaint(WavyPainter old) =>
      old.wavelength != wavelength ||
      old.strokeWidth != strokeWidth ||
      old.padding != padding ||
      old.played != played ||
      old.track != track;
}
