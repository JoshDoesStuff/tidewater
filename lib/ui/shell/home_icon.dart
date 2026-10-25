import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// The Lucide "house" icon (ISC license, https://lucide.dev), drawn in code
/// because its animated version is a React component with no Lottie file.
/// The door draws itself on as [progress] runs 0 to 1; at 0 and 1 the icon is
/// complete, so it can sit in the rail at rest.
class HomeIcon extends StatelessWidget {
  const HomeIcon({super.key, required this.progress, required this.color, this.size = 22});

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _HomePainter(progress, color));
  }
}

class _HomePainter extends CustomPainter {
  _HomePainter(this.progress, this.color);

  final double progress;
  final Color color;

  // Path data is in Lucide's 24 x 24 box.
  static Path _house() => Path()
    ..moveTo(3, 10)
    ..arcToPoint(const Offset(3.709, 8.472), radius: const Radius.circular(2))
    ..lineTo(10.709, 2.473)
    ..arcToPoint(const Offset(13.291, 2.473), radius: const Radius.circular(2))
    ..lineTo(20.291, 8.472)
    ..arcToPoint(const Offset(21, 10), radius: const Radius.circular(2))
    ..lineTo(21, 19)
    ..arcToPoint(const Offset(19, 21), radius: const Radius.circular(2))
    ..lineTo(5, 21)
    ..arcToPoint(const Offset(3, 19), radius: const Radius.circular(2))
    ..close();

  static Path _door() => Path()
    ..moveTo(15, 21)
    ..lineTo(15, 13)
    ..arcToPoint(const Offset(14, 12), radius: const Radius.circular(1), clockwise: false)
    ..lineTo(10, 12)
    ..arcToPoint(const Offset(9, 13), radius: const Radius.circular(1), clockwise: false)
    ..lineTo(9, 21);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(_house(), paint);
    final door = _door();
    if (progress <= 0 || progress >= 1) {
      canvas.drawPath(door, paint);
      return;
    }
    // Draw-on: the door's outline from the start up to `progress` of its length.
    final eased = Curves.easeOutCubic.transform(progress);
    for (final PathMetric m in door.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * eased), paint..color = color.withValues(alpha: eased.clamp(.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(_HomePainter old) => old.progress != progress || old.color != color;
}
