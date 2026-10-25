import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Sidebar icon drawn in code, in the same 24 x 24, 2 px round-stroke style
/// as the Lucide house. At progress 0 and 1 it is the complete resting icon.
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

  // The heart outline from UseAnimations' "heart-v2" (MIT, see
  // third-party-licenses): vertices with in/out tangents, as in its Lottie file.
  static const _v = [
    [20.84, 4.61], [16.95, 2.998], [13.06, 4.61], [12.0, 5.67], [10.94, 4.61], [3.16, 4.61],
    [3.16, 12.39], [4.22, 13.45], [12.0, 21.23], [19.78, 13.45], [20.84, 12.39], [22.452, 8.5],
  ];
  static const _in = [
    [1.032, 1.032], [1.459, 0.0], [1.032, -1.032], [0.0, 0.0], [0.0, 0.0], [2.148, -2.148],
    [-2.148, -2.148], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 1.459],
  ];
  static const _out = [
    [-1.032, -1.032], [-1.459, 0.0], [0.0, 0.0], [0.0, 0.0], [-2.148, -2.148], [-2.148, 2.148],
    [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [1.032, -1.032], [0.0, -1.459],
  ];

  static Path _heart() {
    // Start at the bottom point so the trace grows up from it.
    const start = 8;
    final path = Path()..moveTo(_v[start][0], _v[start][1]);
    for (var j = 0; j < _v.length; j++) {
      final k = (start + j) % _v.length;
      final n = (k + 1) % _v.length;
      path.cubicTo(
        _v[k][0] + _out[k][0], _v[k][1] + _out[k][1],
        _v[n][0] + _in[n][0], _v[n][1] + _in[n][1],
        _v[n][0], _v[n][1],
      );
    }
    return path..close();
  }

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
