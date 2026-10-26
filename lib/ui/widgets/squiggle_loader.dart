import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';

/// The wavy progress bar's buffering look as a loader: a flat track with a
/// squiggle that sweeps along it, standing in for a spinner. It fades in when [active]
/// turns on and out when it turns off (and stops animating once it is gone).
/// With reduced motion it holds still.
class SquiggleLoader extends StatefulWidget {
  const SquiggleLoader({super.key, required this.active, this.height = 16, this.wavelength = 28, this.strokeWidth = 6});

  final bool active;
  final double height;
  final double wavelength;
  final double strokeWidth;

  @override
  State<SquiggleLoader> createState() => _SquiggleLoaderState();
}

class _SquiggleLoaderState extends State<SquiggleLoader> with TickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150));
  late final AnimationController _fade = AnimationController(vsync: this, duration: Motion.medium, reverseDuration: Motion.medium);

  @override
  void initState() {
    super.initState();
    _fade.addStatusListener((s) {
      if (s == AnimationStatus.dismissed) _flow.stop();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SquiggleLoader old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      if (!Motion.reduced(context) && !_flow.isAnimating) _flow.repeat();
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: _fade,
            child: CustomPaint(
              painter: _SquigglePainter(
                flow: _flow,
                color: color,
                track: Theme.of(context).colorScheme.secondaryContainer,
                wavelength: widget.wavelength,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter({
    required this.flow,
    required this.color,
    required this.track,
    required this.wavelength,
    required this.strokeWidth,
  }) : super(repaint: flow);

  final Animation<double> flow;
  final Color color;
  final Color track;
  final double wavelength;
  final double strokeWidth;

  /// The same drawing as the progress bar while it waits for sound: the flat
  /// track shows only either side of the squiggle, and the squiggle (about a
  /// third of the width) sweeps from end to end, its height rising from the line
  /// and falling back to it.
  @override
  void paint(Canvas canvas, Size size) {
    const x0 = 0.0;
    final x1 = size.width;
    final cy = size.height / 2;
    final s = flow.value;
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
    if (to <= from) return;
    final path = Path();
    for (var x = from; x <= to; x += 1.5) {
      final u = ((x - (centerX - span / 2)) / span).clamp(0.0, 1.0);
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
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter old) =>
      old.color != color || old.track != track || old.wavelength != wavelength || old.strokeWidth != strokeWidth;
}
