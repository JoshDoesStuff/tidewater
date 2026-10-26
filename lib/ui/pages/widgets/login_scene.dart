import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/motion.dart';

/// The sign-in backdrop, drawn like the Tidewater banner: a record sinking on
/// the left, a tide across the whole width and a little boat on a wave on the
/// right. The tide drifts, the label turns and the boat follows its wave.
class LoginScene extends StatefulWidget {
  const LoginScene({super.key, required this.recordX, required this.boatX, this.level = .64});

  /// Where the record and the boat sit across the window (0 to 1).
  final double recordX;
  final double boatX;

  /// Where the water's surface is down the window (0 to 1).
  final double level;

  @override
  State<LoginScene> createState() => _LoginSceneState();
}

class _LoginSceneState extends State<LoginScene> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  Ticker? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _ticker?.dispose();
      _ticker = null;
      _time.value = 0;
    } else {
      _ticker ??= createTicker((d) => _time.value = d.inMicroseconds / 1e6)..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScenePainter(time: _time, recordX: widget.recordX, boatX: widget.boatX, level: widget.level),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.time, required this.recordX, required this.boatX, required this.level})
      : super(repaint: time);

  final ValueListenable<double> time;
  final double recordX;
  final double boatX;
  final double level;

  // The banner's numbers (1280 x 640): a tide 380 long and 26 high, the record
  // at .64 of the icon's size, the boat at 1.3.
  static const _length = 380.0;
  static const _amp = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    // Fit the banner's proportions to the window.
    final s = math.min(size.height / 640, size.width / 1100);
    final lvl = size.height * level;
    final length = _length * s;
    final amp = _amp * s;
    final drift = t * .55;
    double wave(double x, {double drop = 0, double a = 1, double ph = 0}) =>
        lvl + drop * s + amp * a * math.sin(2 * math.pi * x / length + drift + ph);

    canvas.drawRect(Offset.zero & size, Paint()..color = AppTheme.brandBlue);

    // The record, a little sunk, as in the icon.
    _record(canvas, Offset(size.width * recordX, lvl - 88 * s), .64 * s, t);

    // The boat: on its wave, leaning with the slope, drawn before the water so
    // the water covers the bottom of the hull.
    final bx = size.width * boatX;
    final slope = amp * 2 * math.pi / length * math.cos(2 * math.pi * bx / length + drift);
    final tilt = math.atan(slope).clamp(-.12, .12) - .08;
    _boat(canvas, bx, wave(bx) - 2 * s, tilt, 1.3 * s);

    Path line({double drop = 0, double a = 1, double ph = 0, bool fill = false}) {
      final p = Path()..moveTo(-8, wave(-8, drop: drop, a: a, ph: ph));
      for (var x = 0.0; x <= size.width + 8; x += 8) {
        p.lineTo(x, wave(x, drop: drop, a: a, ph: ph));
      }
      if (fill) {
        p
          ..lineTo(size.width + 8, size.height + 8)
          ..lineTo(-8, size.height + 8)
          ..close();
      }
      return p;
    }

    Paint stroke(Color color, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    canvas.drawPath(line(fill: true), Paint()..color = AppTheme.brandWater);
    canvas.drawPath(line(drop: 70, a: .77, ph: 1.6), stroke(AppTheme.brandWaterLine, 10 * s));
    canvas.drawPath(line(drop: 150, a: .62, ph: 3.1), stroke(AppTheme.brandWaterLine, 8 * s));
    canvas.drawPath(line(), stroke(AppTheme.brandSurface, 18 * s));
  }

  /// The icon's record at [k] times its 1024 px drawing.
  void _record(Canvas canvas, Offset c, double k, double t) {
    Paint ring(Color color, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * k
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, 250 * k, ring(AppTheme.brandLine, 30));
    canvas.drawCircle(c, 180 * k, ring(AppTheme.brandGroove1, 14));
    canvas.drawCircle(c, 132 * k, ring(AppTheme.brandGroove2, 10));
    canvas.drawArc(Rect.fromCircle(center: c, radius: 218 * k), 3.55, .6, false, ring(AppTheme.brandShine, 16));
    // The scalloped label turns slowly.
    final label = Path();
    for (var i = 0; i < 240; i++) {
      final a = 2 * math.pi * i / 240 - math.pi / 2;
      final r = 88 * k * (1 + .085 * math.cos(6 * a));
      final p = Offset(c.dx + r * math.cos(a + t * .3), c.dy + r * math.sin(a + t * .3));
      i == 0 ? label.moveTo(p.dx, p.dy) : label.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(label..close(), Paint()..color = AppTheme.seed);
    canvas.drawCircle(c, 18 * k, Paint()..color = AppTheme.brandHole);
  }

  /// The icon's boat: a pennant flag, a mast and a shallow hull with curved
  /// ends. ([x], [by]) is the bottom of the hull.
  void _boat(Canvas canvas, double x, double by, double tilt, double scale) {
    Offset p(double dx, double dy) {
      final lx = dx * scale;
      final ly = (dy - 10) * scale;
      return Offset(
        x + math.cos(tilt) * lx - math.sin(tilt) * ly,
        by + math.sin(tilt) * lx + math.cos(tilt) * ly,
      );
    }

    Offset curve(Offset a, Offset c, Offset b, double t) => Offset(
          (1 - t) * (1 - t) * a.dx + 2 * (1 - t) * t * c.dx + t * t * b.dx,
          (1 - t) * (1 - t) * a.dy + 2 * (1 - t) * t * c.dy + t * t * b.dy,
        );
    Path poly(List<Offset> pts) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      return path..close();
    }

    Offset q(Offset o) => p(o.dx, o.dy);
    final hull = poly([
      p(-52, -16),
      p(52, -16),
      for (var i = 1; i <= 8; i++) q(curve(const Offset(52, -16), const Offset(47, 10), const Offset(28, 10), i / 8)),
      for (var i = 1; i <= 8; i++) q(curve(const Offset(-28, 10), const Offset(-47, 10), const Offset(-52, -16), i / 8)),
    ]);
    final flag = poly([p(3, -96), p(3, -64), p(46, -80)]);

    Paint edge(Color color, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawLine(p(0, -98), p(0, -16), edge(AppTheme.brandSail, 6));
    canvas.drawPath(flag, Paint()..color = AppTheme.brandSail);
    canvas.drawPath(flag, edge(AppTheme.brandSail, 5));
    canvas.drawPath(hull, Paint()..color = AppTheme.seed);
    canvas.drawPath(hull, edge(AppTheme.seed, 5));
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.recordX != recordX || old.boatX != boatX || old.level != level;
}
