import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/destinations.dart';
import 'home_icon.dart';

/// The one-shot animation a sidebar icon plays when its page is selected.
/// [t] runs 0 to 1; every motion ends where it started. Each destination has
/// its own so the rail feels alive without all icons doing the same thing.
Widget railIconMotion(Destination d, double t, Color color, {double size = 22}) {
  // Home is the Lucide house, drawn in code; its door draws itself on.
  if (d == Destination.home) return HomeIcon(progress: t, color: color, size: size);
  final icon = Icon(d.icon, size: size, color: color);
  if (t == 0 || t == 1) return icon;
  final decay = 1 - t;
  switch (d) {
    case Destination.home:
      return icon;
    // Two cards shuffling past each other.
    case Destination.library:
      final swap = math.sin(math.pi * t);
      final front = t < .5;
      Widget card(double dx, double tilt, double opacity) => Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.rotate(angle: tilt, child: Opacity(opacity: opacity, child: icon)),
          );
      return Stack(
        alignment: Alignment.center,
        children: [
          card(-7 * swap, -.18 * swap, front ? .55 : 1),
          card(7 * swap, .18 * swap, front ? 1 : .55),
        ],
      );
    // Takes a bow: sways side to side from the feet.
    case Destination.artists:
      return Transform.scale(
        scale: 1 + .12 * math.sin(math.pi * t),
        child: Transform.rotate(
          angle: .32 * math.sin(t * math.pi * 2.5) * decay,
          alignment: Alignment.bottomCenter,
          child: icon,
        ),
      );
    // Double heartbeat.
    case Destination.liked:
      final beat = math.max(math.pow(math.sin(math.pi * (t * 2).clamp(0, 1)), 2), .8 * math.pow(math.sin(math.pi * ((t - .5) * 2).clamp(0, 1)), 2));
      return Transform.scale(scale: 1 + .38 * beat * (1 - t * .4), child: icon);
    // The list scrolls: the icon slides out the top and back in from below.
    case Destination.lists:
      final y = t < .5 ? -(t * 2) * (size + 6) : (1 - (t - .5) * 2) * (size + 6);
      return ClipRect(
        child: SizedBox(
          width: size + 6,
          height: size + 6,
          child: Transform.translate(offset: Offset(0, y), child: Center(child: icon)),
        ),
      );
    // Tuning: the dial sweeps one way then the other while signal rings pulse out.
    case Destination.radio:
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _RingsPainter(t, color)),
          Transform.rotate(angle: .5 * math.sin(t * math.pi * 3) * decay, child: icon),
        ],
      );
    // Gear turns a half revolution and settles.
    case Destination.settings:
      return Transform.rotate(angle: math.pi * Curves.easeOutBack.transform(t), child: icon);
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 2; i++) {
      final p = ((t * 1.6) - i * .3).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        c,
        size.width * (.45 + .55 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: .5 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t || old.color != color;
}
