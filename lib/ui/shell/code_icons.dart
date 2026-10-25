import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Sidebar icons drawn in code, in the same 24 x 24, 2 px round-stroke style
/// as the Lucide house. At progress 0 and 1 each is the complete resting icon.
Paint _stroke(Color color) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

/// A heart that traces itself from the bottom point, then gives one pop
/// outward. It never shrinks, so it doesn't fight the press shrink on the rail.
class HeartIcon extends StatelessWidget {
  const HeartIcon({super.key, required this.progress, required this.color, this.size = 22});

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _HeartPainter(progress, color));
}

class _HeartPainter extends CustomPainter {
  _HeartPainter(this.progress, this.color);

  final double progress;
  final Color color;

  static Path _heart() => Path()
    ..moveTo(12, 21)
    ..cubicTo(12, 21, 3, 14.5, 3, 8.5)
    ..cubicTo(3, 5.4, 5.4, 3, 8.3, 3)
    ..cubicTo(10, 3, 11.5, 3.9, 12, 5.2)
    ..cubicTo(12.5, 3.9, 14, 3, 15.7, 3)
    ..cubicTo(18.6, 3, 21, 5.4, 21, 8.5)
    ..cubicTo(21, 14.5, 12, 21, 12, 21)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final running = progress > 0 && progress < 1;
    // Trace in the first 60%, pop in the rest.
    final trace = running ? Curves.easeOutCubic.transform((progress / .6).clamp(0.0, 1.0)) : 1.0;
    final pop = running ? math.sin(math.pi * ((progress - .5) / .5).clamp(0.0, 1.0)) : 0.0;
    final grow = 1 + .16 * pop;
    canvas.translate(12, 12);
    canvas.scale(grow);
    canvas.translate(-12, -12);
    final paint = _stroke(color);
    if (trace >= 1) {
      // A faint fill at the peak of the pop makes it read as a heartbeat.
      if (pop > 0) canvas.drawPath(_heart(), Paint()..color = color.withValues(alpha: .28 * pop));
      canvas.drawPath(_heart(), paint);
      return;
    }
    for (final PathMetric m in _heart().computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * trace), paint);
    }
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.progress != progress || old.color != color;
}

/// Books on a shelf: two stand up and hop in turn while the leaning one
/// swings upright and tips back.
class LibraryIcon extends StatelessWidget {
  const LibraryIcon({super.key, required this.progress, required this.color, this.size = 22});

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LibraryPainter(progress, color));
}

class _LibraryPainter extends CustomPainter {
  _LibraryPainter(this.progress, this.color);

  final double progress;
  final Color color;

  /// How far the leaning book rests off vertical.
  static const _lean = .3;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = _stroke(color);
    final running = progress > 0 && progress < 1;

    // Hop for book [i]: a bump in its own slice of the animation.
    double hop(int i) {
      if (!running) return 0;
      final p = ((progress - i * .12) / .4).clamp(0.0, 1.0);
      return math.sin(math.pi * p);
    }

    RRect book(double x, double top) => RRect.fromRectAndRadius(Rect.fromLTWH(x, top, 4, 20 - top), const Radius.circular(1));

    canvas.save();
    canvas.translate(0, -2.5 * hop(0));
    canvas.drawRRect(book(3, 5), paint);
    canvas.restore();

    canvas.save();
    canvas.translate(0, -2.5 * hop(1));
    canvas.drawRRect(book(9, 3), paint);
    canvas.restore();

    // The leaning book pivots on its bottom-right corner: it swings up past
    // vertical and settles back to its lean.
    final swing = running ? (math.sin(math.pi * progress * 1.5) * (1 - progress * .5)) : 0.0;
    final angle = _lean * (1 - 1.6 * swing);
    canvas.save();
    canvas.translate(19, 20);
    canvas.rotate(-angle);
    canvas.translate(-19, -20);
    canvas.drawRRect(book(15, 4), paint);
    canvas.restore();

    // The shelf.
    canvas.drawLine(const Offset(2, 21.5), const Offset(22, 21.5), paint);
  }

  @override
  bool shouldRepaint(_LibraryPainter old) => old.progress != progress || old.color != color;
}
