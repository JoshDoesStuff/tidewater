import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart';

import '../../../app/theme/motion.dart';

/// The sign-in backdrop: a record for a sun low over the water, layers of
/// slow waves and a small boat riding them. All colors come from the scheme.
class LoginScene extends StatefulWidget {
  const LoginScene({
    super.key,
    required this.sunX,
    required this.boatX,
    required this.horizon,
    required this.accent,
  });

  /// Where the sun sits across the window (0 to 1).
  final double sunX;

  /// Where the boat rides across the window (0 to 1).
  final double boatX;

  /// The record label and the hull (the icon's coral).
  final Color accent;

  /// Where the water starts down the window (0 to 1).
  final double horizon;

  @override
  State<LoginScene> createState() => _LoginSceneState();
}

class _LoginSceneState extends State<LoginScene>
    with SingleTickerProviderStateMixin {
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
      _ticker ??= createTicker((d) => _time.value = d.inMicroseconds / 1e6)
        ..start();
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
        painter: _ScenePainter(
          scheme: Theme.of(context).colorScheme,
          time: _time,
          sunX: widget.sunX,
          boatX: widget.boatX,
          accent: widget.accent,
          horizon: widget.horizon,
        ),
      ),
    );
  }
}

class _Wave {
  const _Wave(
    this.depth,
    this.amp,
    this.length,
    this.speed,
    this.phase,
    this.tone,
  );

  /// 0 at the horizon, 1 at the bottom edge.
  final double depth;
  final double amp;
  final double length;
  final double speed;
  final double phase;

  /// How much of the sun color the layer keeps (far water is lighter).
  final double tone;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.scheme,
    required this.time,
    required this.sunX,
    required this.boatX,
    required this.horizon,
    required this.accent,
  }) : super(repaint: time);

  final ColorScheme scheme;
  final ValueListenable<double> time;
  final double sunX;
  final double boatX;
  final Color accent;
  final double horizon;

  static const _waves = [
    _Wave(.02, 3, 220, .5, 0, .62),
    _Wave(.16, 7, 420, .35, 1.7, .52),
    _Wave(.42, 12, 640, .28, 3.1, .4),
    _Wave(.72, 18, 860, .22, 4.4, .26),
  ];

  double _y(_Wave w, double x, double t, Size size) {
    final top = size.height * horizon;
    final base = top + (size.height - top) * w.depth;
    final k = 2 * math.pi / w.length;
    return base +
        w.amp * math.sin(x * k + t * w.speed + w.phase) +
        w.amp * .35 * math.sin(x * k * 2.3 - t * w.speed * 1.4);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final hz = size.height * horizon;
    final skyLow = Color.lerp(scheme.surface, scheme.primaryContainer, .5)!;

    // Sky.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surface, skyLow],
        ).createShader(Rect.fromLTWH(0, 0, size.width, hz)),
    );

    // Sun: a record, rising a little over the horizon and turning slowly.
    final r = math.min(size.width, size.height) * .24;
    final sun = Offset(size.width * sunX, hz - r * .35);
    canvas.drawCircle(
      sun,
      r * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            scheme.primary.withValues(alpha: .28),
            scheme.primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 2.6)),
    );
    _record(canvas, sun, r, t);

    // The far water, then the sun's glitter on it.
    _layer(canvas, size, _waves[0], t);
    _glitter(canvas, size, sun, r, t);
    _layer(canvas, size, _waves[1], t);

    // The boat rides the second layer, behind the nearer water.
    final bx = size.width * boatX;
    _boat(canvas, size, bx, t);

    _layer(canvas, size, _waves[2], t);
    _layer(canvas, size, _waves[3], t);
  }

  void _record(Canvas canvas, Offset c, double r, double t) {
    canvas.drawCircle(c, r, Paint()..color = scheme.primaryContainer);
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .035
      ..color = scheme.onPrimaryContainer.withValues(alpha: .22);
    for (final f in const [.9, .78, .66, .54]) {
      canvas.drawCircle(c, r * f, groove);
    }
    // A shine that stays put while the label turns.
    final shine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .06
      ..strokeCap = StrokeCap.round
      ..color = scheme.onPrimaryContainer.withValues(alpha: .3);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * .84),
      3.5,
      .7,
      false,
      shine,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * .84),
      3.5 + math.pi,
      .7,
      false,
      shine,
    );
    // Label with a notch so the turning shows.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * .25);
    canvas.drawCircle(Offset.zero, r * .34, Paint()..color = accent);
    canvas.drawCircle(
      Offset(0, -r * .22),
      r * .045,
      Paint()..color = scheme.onPrimary.withValues(alpha: .7),
    );
    canvas.restore();
    canvas.drawCircle(c, r * .05, Paint()..color = scheme.surface);
  }

  void _layer(Canvas canvas, Size size, _Wave w, double t) {
    final path = Path()..moveTo(0, size.height);
    final crest = Path();
    for (var x = 0.0; x <= size.width + 8; x += 8) {
      final y = _y(w, x, t, size);
      path.lineTo(x, y);
      x == 0 ? crest.moveTo(x, y) : crest.lineTo(x, y);
    }
    path
      ..lineTo(size.width + 8, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(scheme.surface, scheme.primaryContainer, w.tone)!,
    );
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = scheme.primary.withValues(alpha: .22 * (1 - w.depth * .6)),
    );
  }

  /// Short bright dashes under the sun that shimmer and thin out downward.
  void _glitter(Canvas canvas, Size size, Offset sun, double r, double t) {
    final hz = size.height * horizon;
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var i = 0; i < 14; i++) {
      final f = i / 14;
      final y = hz + 10 + f * (size.height - hz) * .5;
      final half = r * (.7 - f * .45) * (.6 + .4 * math.sin(t * 1.3 + i * 1.7));
      final dx = 14 * math.sin(t * .6 + i);
      p.color = scheme.primary.withValues(
        alpha: (.5 * (1 - f)).clamp(0.0, 1.0),
      );
      canvas.drawLine(
        Offset(sun.dx + dx - half, y),
        Offset(sun.dx + dx + half, y),
        p,
      );
    }
  }

  void _boat(Canvas canvas, Size size, double x, double t) {
    final w = _waves[1];
    final y = _y(w, x, t, size);
    final slope = math.atan2(
      _y(w, x + 24, t, size) - _y(w, x - 24, t, size),
      48,
    );
    final s = math.min(size.width, size.height) / 900 * 1.25;
    canvas.save();
    canvas.translate(x, y + 4 * s);
    canvas.rotate(slope * .8 + .04 * math.sin(t * .9));
    canvas.scale(s);

    final sail = Paint()..color = scheme.onSurface;
    final hull = Paint()..color = accent;
    canvas.drawPath(
      Path()
        ..moveTo(3, -92)
        ..lineTo(3, -16)
        ..lineTo(48, -16)
        ..close(),
      sail,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-3, -78)
        ..lineTo(-3, -16)
        ..lineTo(-34, -16)
        ..close(),
      Paint()..color = scheme.onSurface.withValues(alpha: .8),
    );
    canvas.drawLine(
      const Offset(0, -98),
      const Offset(0, -12),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = scheme.onSurfaceVariant,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-44, -12)
        ..lineTo(52, -12)
        ..quadraticBezierTo(44, 14, 20, 18)
        ..lineTo(-24, 18)
        ..quadraticBezierTo(-40, 12, -44, -12)
        ..close(),
      hull,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.scheme != scheme ||
      old.sunX != sunX ||
      old.boatX != boatX ||
      old.accent != accent ||
      old.horizon != horizon;
}
