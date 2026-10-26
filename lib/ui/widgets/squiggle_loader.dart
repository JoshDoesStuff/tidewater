import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';

/// A thin squiggle that ripples along its width while something loads: the
/// app's wavy progress bar standing in for a spinner. It fades in when [active]
/// turns on and out when it turns off (and stops animating once it is gone).
/// With reduced motion it holds still.
class SquiggleLoader extends StatefulWidget {
  const SquiggleLoader({super.key, required this.active, this.height = 16, this.amplitude = 4, this.wavelength = 26});

  final bool active;
  final double height;
  final double amplitude;
  final double wavelength;

  @override
  State<SquiggleLoader> createState() => _SquiggleLoaderState();
}

class _SquiggleLoaderState extends State<SquiggleLoader> with TickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
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
                amplitude: widget.amplitude,
                wavelength: widget.wavelength,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter({required this.flow, required this.color, required this.amplitude, required this.wavelength})
      : super(repaint: flow);

  final Animation<double> flow;
  final Color color;
  final double amplitude;
  final double wavelength;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final phase = flow.value * 2 * math.pi;
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 2) {
      // The ends taper to the line, so the wave grows out of it.
      final edge = math.min(1.0, math.min(x, size.width - x) / 36);
      // Ripples travel left to right.
      final y = cy + amplitude * edge * math.sin(2 * math.pi * x / wavelength - phase);
      x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter old) =>
      old.color != color || old.amplitude != amplitude || old.wavelength != wavelength;
}
