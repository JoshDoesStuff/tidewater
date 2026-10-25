import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The sidebar's Liked heart. It is the same Material heart as the like buttons
/// in the mini player and Now Playing (outline at rest), so they match. On
/// select it fills in and pops, then settles back to the outline; at progress
/// 0 and 1 it is the plain outline.
class HeartIcon extends StatelessWidget {
  const HeartIcon({super.key, required this.progress, required this.color, this.size = 22});

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _HeartPainter(progress, color));
}

class _HeartPainter extends CustomPainter {
  _HeartPainter(this.progress, this.color);

  final double progress;
  final Color color;

  void _glyph(Canvas canvas, Size size, IconData icon, double alpha) {
    if (alpha <= 0) return;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size.width,
          color: color.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final running = progress > 0 && progress < 1;
    final beat = running ? math.sin(math.pi * progress) : 0.0;
    final grow = 1 + .24 * (running ? math.sin(math.pi * (progress / .7).clamp(0.0, 1.0)) : 0.0);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(grow);
    canvas.translate(-size.width / 2, -size.height / 2);
    _glyph(canvas, size, Icons.favorite_border_rounded, 1);
    // The filled heart fades in over the outline and back out; the outline
    // underneath keeps the icon from ever disappearing.
    _glyph(canvas, size, Icons.favorite_rounded, beat);
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.progress != progress || old.color != color;
}
