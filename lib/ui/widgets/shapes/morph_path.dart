import 'dart:math' as math;
import 'dart:ui';

/// A scalloped outline: radius `R * base * (1 + amp * cos(lobes * θ + rot))`.
class ShapeParams {
  const ShapeParams({required this.lobes, required this.amp, required this.base});

  final int lobes;
  final double amp;
  final double base;

  ShapeParams copyWith({int? lobes, double? amp, double? base}) =>
      ShapeParams(lobes: lobes ?? this.lobes, amp: amp ?? this.amp, base: base ?? this.base);

  @override
  bool operator ==(Object other) =>
      other is ShapeParams && other.lobes == lobes && other.amp == amp && other.base == base;

  @override
  int get hashCode => Object.hash(lobes, amp, base);
}

/// The named shapes from the demo.
enum ShapeKind {
  cookie(ShapeParams(lobes: 9, amp: .06, base: .955)),
  clover(ShapeParams(lobes: 4, amp: .14, base: .9)),
  sunny(ShapeParams(lobes: 8, amp: .10, base: .9)),
  flower(ShapeParams(lobes: 6, amp: .13, base: .88)),
  scallop(ShapeParams(lobes: 12, amp: .045, base: .95)),
  circle(ShapeParams(lobes: 1, amp: 0, base: 1));

  const ShapeKind(this.params);
  final ShapeParams params;

  /// Kind used for the item at [index] (cards are assigned a shape by index).
  static ShapeKind forIndex(int index) => values[index % 5];

  /// Kind for an album id: stable across runs, so an album keeps its shape
  /// wherever it appears (grid card, mini player, Now Playing).
  static ShapeKind forKey(String key) {
    var h = 0x811c9dc5; // FNV-1a
    for (final c in key.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return values[h % 5];
  }
}

/// Outline at morph factor [m] (0 = superellipse, 1 = lobed shape).
///
/// With [squareBase] false the outline is always the polar shape (used by the
/// halo and ambient blobs). [m] may overshoot [0, 1] while a spring settles.
Path morphPath(
  Size size, {
  required double m,
  required ShapeParams params,
  double rot = 0,
  bool squareBase = true,
  double exponent = 4.2,
  int points = 120,
}) {
  final r = size.shortestSide / 2;
  final center = size.center(Offset.zero);
  final e = 2 / exponent;
  // Lobe tips reach base * (1 + amp) * R. When that is above 1 (cookie, clover,
  // the halo) the widget's box would slice the tips flat, so shrink the lobed
  // outline just enough to stay inside it.
  final fit = math.min(1.0, 1 / (params.base * (1 + params.amp)));
  final path = Path();
  for (var k = 0; k < points; k++) {
    final th = k / points * 2 * math.pi - math.pi / 2;
    final co = math.cos(th);
    final si = math.sin(th);
    final pr = r * fit * params.base * (1 + params.amp * math.cos(params.lobes * th + rot));
    final px = pr * co;
    final py = pr * si;
    double x;
    double y;
    if (squareBase) {
      final sx = r * co.sign * math.pow(co.abs(), e);
      final sy = r * si.sign * math.pow(si.abs(), e);
      x = sx * (1 - m) + px * m;
      y = sy * (1 - m) + py * m;
    } else {
      x = px;
      y = py;
    }
    if (k == 0) {
      path.moveTo(center.dx + x, center.dy + y);
    } else {
      path.lineTo(center.dx + x, center.dy + y);
    }
  }
  return path..close();
}
