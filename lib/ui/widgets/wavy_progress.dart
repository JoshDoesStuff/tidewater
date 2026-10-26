import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/providers/settings_providers.dart';
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

  /// While true the shown fraction chases its target quickly instead of
  /// following the playhead: the wave retracts to empty on a new track or when
  /// buffering starts, and squiggles back up to the playhead when it ends.
  bool animating = false;
  double display = 0;
  double animFrom = 0;

  /// 0 to 1 through the current transition, and how long it takes in seconds
  /// (set on its first frame, longer for a longer way to travel).
  double animT = 0;
  double animDur = -1;

  /// A seek (a click on the bar): the wave travels to the new spot and the
  /// handle stays, unlike a track change or buffering where it slips away.
  bool seekAnim = false;

  /// 1 while the buffering squiggle is wanted; it fades out, not vanishes, when
  /// the wait is over.
  double sweepAlpha = 0;

  /// The handle shrinks into the end dot once the playhead is over it.
  double dotShrink = 0;

  /// The fraction drawn last, where a transition starts from.
  double lastFrac = 0;

  /// 0 (gone) to 1 (full size): the playhead handle shrinks away during those
  /// transitions and grows back when they are done.
  double handle = 1;

  /// Where the handle is while dragging with live scrubbing off; the seek is
  /// only requested when it is let go.
  double? scrubFrac;
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
  Duration _duration = Duration.zero;
  String? _trackId;

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

  double _realFraction() =>
      _duration.inMicroseconds == 0 ? 0 : _estimate(_duration).inMicroseconds / _duration.inMicroseconds;

  /// The fraction to draw: the playhead, or the transition value while the
  /// wave is retracting or squiggling back, or the dragged position.
  double _frac() {
    final f = _model.scrubFrac ?? ((_model.animating || _buffering) ? _model.display : _realFraction());
    return _model.lastFrac = f;
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

  /// Starts the quick retract / squiggle-back from whatever is on screen now.
  void _beginTransition({bool seek = false}) {
    if (_reduced) {
      _model.animating = false;
      return;
    }
    _model.seekAnim = seek;
    _model.animFrom = _model.lastFrac;
    _model.display = _model.lastFrac;
    _model.animT = 0;
    _model.animDur = -1;
    _model.animating = true;
  }

  double get _handleTarget => ((_model.animating && !_model.seekAnim) || _buffering || !_playing) && !_model.dragging ? 0 : 1;

  /// Where the end dot sits, as a fraction of the bar.
  double _dotFraction() {
    final w = context.size?.width ?? 0;
    final span = w - 2 * widget.padding;
    return span <= 0 ? 1 : (span - 3) / span;
  }

  void _sync() {
    final source = ref.read(visualizerSourceProvider);
    if (_reduced) {
      _ticker?.stop();
      _model.amplitude = _playing ? widget.amplitude : 0;
      _model.animating = false;
      _model.handle = _handleTarget;
      _frame.value++;
      return;
    }
    final needed = _playing ||
        _buffering ||
        _model.animating ||
        _model.sweepAlpha > 0 ||
        _model.dotShrink > 0 ||
        _model.handle != _handleTarget ||
        _model.amplitude > .02;
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
    if (_buffering || _model.sweepAlpha > 0) _model.sweep = (_model.sweep + dt / 1.15) % 1;
    _model.sweepAlpha = _buffering ? 1 : math.max(0, _model.sweepAlpha - dt / .18);

    // The squiggle back up waits until the buffering squiggle has faded, so the
    // two never share the bar.
    if (_model.animating && (_buffering || _model.sweepAlpha <= 0)) {
      final target = _buffering ? 0.0 : _realFraction();
      if (_model.animDur < 0) {
        final dist = (target - _model.animFrom).abs();
        _model.animDur = _model.seekAnim ? .22 + .38 * dist : .35 + .45 * dist;
      }
      _model.animT = math.min(1.0, _model.animT + dt / _model.animDur);
      final e = Curves.easeInOutCubic.transform(_model.animT);
      _model.display = _model.animFrom + (target - _model.animFrom) * e;
      if (_model.animT >= 1) {
        _model.display = target;
        _model.animating = false;
        _model.seekAnim = false;
      }
    }
    final atDot = !_buffering && !_model.animating && _frac() >= _dotFraction();
    _model.dotShrink = (_model.dotShrink + (atDot ? dt : -dt) / .14).clamp(0.0, 1.0);
    final handleTarget = _handleTarget;
    final step = dt * 7;
    _model.handle += (handleTarget - _model.handle).clamp(-step, step);

    _frame.value++;
    if (!_playing &&
        !_buffering &&
        !_model.animating &&
        _model.sweepAlpha == 0 &&
        _model.dotShrink == 0 &&
        _model.handle == handleTarget &&
        _model.amplitude < .02) {
      _model.amplitude = 0;
      _ticker?.stop();
    }
  }

  double _fractionAt(double dx) {
    final w = context.size?.width ?? 1;
    return (dx / w).clamp(0.0, 1.0);
  }

  void _seekTo(double f, {bool animate = false}) {
    // A click away from the playhead: the wave squiggles there, not jumps.
    if (animate && (f - _model.lastFrac).abs() > .004) _beginTransition(seek: true);
    // Show the new spot at once; the engine's report catches up a moment later.
    _anchorPos = Duration(microseconds: (_duration.inMicroseconds * f).round());
    _anchorAt = _clock.elapsed;
    ref.read(playbackProvider.notifier).seekFraction(f);
    _frame.value++;
  }

  /// A drag moved to [dx]: seek right away (live scrubbing), or just show it
  /// and wait for the drop, so one seek is requested instead of dozens.
  void _scrub(double dx) {
    final f = _fractionAt(dx);
    if (ref.read(liveScrubProvider)) {
      _seekTo(f);
    } else {
      _model.scrubFrac = f;
      _frame.value++;
    }
  }

  void _endDrag({bool cancel = false}) {
    final f = _model.scrubFrac;
    _model.scrubFrac = null;
    if (f != null && !cancel) _seekTo(f, animate: true);
    _setDragging(false);
  }

  void _setDragging(bool v) {
    _model.dragging = v;
    _frame.value++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
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
    final trackId = ref.watch(currentTrackIdProvider);
    final position = ref.watch(positionProvider);
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final buffering = ref.watch(playbackProvider.select((s) => s.buffering));
    _duration = duration;
    if (_trackId != trackId) {
      // A new track: the handle slips away and the wave runs back to empty.
      if (_trackId != null) _beginTransition();
      _trackId = trackId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
    if (buffering != _buffering) {
      // Hold the bar where it is while waiting, and let go when sound starts.
      _beginTransition();
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
        // A tap seeks once it is a tap, not when the finger lands, so the start
        // of a drag doesn't trigger a seek of its own.
        onTapUp: (d) => _seekTo(_fractionAt(d.localPosition.dx), animate: true),
        onHorizontalDragStart: (d) {
          _setDragging(true);
          _scrub(d.localPosition.dx);
        },
        onHorizontalDragUpdate: (d) => _scrub(d.localPosition.dx),
        onHorizontalDragEnd: (_) => _endDrag(),
        onHorizontalDragCancel: () => _endDrag(cancel: true),
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: WavyPainter(
              repaint: Listenable.merge([position, _frame]),
              fraction: _frac,
              amplitude: () => _model.amplitude,
              phase: () => _model.phase,
              dragging: () => _model.dragging,
              buffering: () => _model.buffering,
              sweep: () => _reduced ? .5 : _model.sweep,
              handle: () => _model.handle,
              dotShrink: () => _model.dotShrink,
              sweepAlpha: () => _model.sweepAlpha,
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
    required this.handle,
    required this.dotShrink,
    required this.sweepAlpha,
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

  /// 0 to 1: how much of the playhead handle is showing.
  final double Function() handle;

  /// 0 to 1: the handle shrinking into the end dot.
  final double Function() dotShrink;

  /// 0 to 1: how visible the buffering squiggle still is as it fades out.
  final double Function() sweepAlpha;
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
    final frac = fraction();
    // Once the wave has run back to empty, a buffering bar is the sweeping
    // squiggle (which then fades before the wave grows back).
    if ((buffering() || sweepAlpha() > 0) && frac < .01) {
      _paintBuffering(canvas, x0, x1, cy, buffering() ? 1 : sweepAlpha());
      return;
    }
    // The playhead stops at the end dot rather than running past it.
    final xp = math.min(x0 + (x1 - x0) * frac, x1 - 3);
    final amp = amplitude();
    final ph = phase();
    final h = Curves.easeOut.transform(handle().clamp(0.0, 1.0));

    // Played portion: a sine path that ends 6 px before the handle (right at
    // the playhead while the handle is away). Sampled finely (about 20 points
    // per wavelength) so it reads as a smooth curve, and the final point is
    // explicit so the length grows continuously instead of in sampling jumps.
    final wave = wavePath(
      start: x0,
      end: math.max(x0, xp - 6 * h),
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

    // Handle: grows while dragging, scales in and out with [handle]. At the end
    // of the bar it stops over the dot and shrinks into it, fast.
    final into = Curves.easeIn.transform(dotShrink().clamp(0.0, 1.0));
    final scale = h * (1 - into);
    if (scale > .02) {
      final hx = xp;
      final hw = (dragging() ? 2.5 : 4.0) * scale;
      final hh = math.min(13.0, size.height * .32) * scale;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(hx - hw / 2, cy - hh, hw, hh * 2), Radius.circular(hw / 2)),
        Paint()..color = played,
      );
    }

    // Remaining track and end dot.
    final trackLeft = xp + strokeWidth * 1.3 * h;
    if (x1 > trackLeft) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(trackLeft, cy - strokeWidth / 2, x1, cy + strokeWidth / 2),
          Radius.circular(strokeWidth / 2),
        ),
        Paint()..color = track,
      );
    }
    // The dot goes with the handle that shrinks into it.
    final dotAlpha = 1 - into;
    if (dotAlpha > 0) canvas.drawCircle(Offset(x1 - 3, cy), 2, Paint()..color = played.withValues(alpha: dotAlpha));
  }

  /// Waiting for sound: a flat track with a squiggle that sweeps along it. The
  /// bar under the squiggle is the squiggle (no gray shows behind it), and
  /// there is no handle.
  void _paintBuffering(Canvas canvas, double x0, double x1, double cy, double alpha) {
    final s = sweep();
    final span = math.max(60.0, (x1 - x0) * .38);
    final centerX = x0 - span / 2 + (x1 - x0 + span) * s;
    final from = math.max(x0, centerX - span / 2);
    final to = math.min(x1, centerX + span / 2);
    final r = Radius.circular(strokeWidth / 2);
    final bar = Paint()..color = track;
    final left = math.min(from, x1);
    final right = math.max(to, x0);
    if (left > x0) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x0, cy - strokeWidth / 2, left, cy + strokeWidth / 2), r), bar);
    }
    if (x1 > right) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(right, cy - strokeWidth / 2, x1, cy + strokeWidth / 2), r), bar);
    }
    _paintSweep(canvas, x0, x1, cy, alpha);
  }

  /// The sweeping squiggle itself, at [alpha] strength.
  void _paintSweep(Canvas canvas, double x0, double x1, double cy, double alpha) {
    final s = sweep();
    final span = math.max(60.0, (x1 - x0) * .38);
    final centerX = x0 - span / 2 + (x1 - x0 + span) * s;
    final from = math.max(x0, centerX - span / 2);
    final to = math.min(x1, centerX + span / 2);
    if (to <= from) return;
    final path = Path();
    for (var x = from; x <= to; x += 1.5) {
      final u = ((x - (centerX - span / 2)) / span).clamp(0.0, 1.0);
      // Ramp the height up from the bar's ends so the squiggle grows out of the
      // line instead of starting mid-wave at the edge.
      final edge = math.min(1.0, math.min((x - x0) / 16, (x1 - x) / 16));
      final y = cy + 4 * edge * math.sin(math.pi * u) * math.sin(2 * math.pi * (x / wavelength - s * 3));
      x == from ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = played.withValues(alpha: alpha),
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
