import 'dart:math' as math;
import 'dart:ui';

/// Superellipse ("squircle") outline fitted to the shortest side of [size].
///
/// This is the resting state of the art tiles; the morph to scalloped shapes
/// arrives with `MorphShape` in milestone 4.
Path squirclePath(Size size, {double exponent = 4.2, int points = 120}) {
  final r = size.shortestSide / 2;
  final center = size.center(Offset.zero);
  final e = 2 / exponent;
  final path = Path();
  for (var k = 0; k < points; k++) {
    final th = k / points * 2 * math.pi - math.pi / 2;
    final c = math.cos(th);
    final s = math.sin(th);
    final x = center.dx + r * c.sign * math.pow(c.abs(), e);
    final y = center.dy + r * s.sign * math.pow(s.abs(), e);
    if (k == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}
