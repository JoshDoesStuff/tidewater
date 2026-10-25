import 'package:flutter/animation.dart';

/// A cubic Bézier easing solved exactly, like CSS `cubic-bezier()`.
///
/// Flutter's `Cubic` finds the curve's parameter by bisection with a 0.001
/// tolerance, so its output carries up to ~0.004 of noise that changes from
/// frame to frame. On a large moving title (.65em at 58 px) that is a visible
/// 0.2-0.3 px shimmer; browsers solve this precisely, so the demo has none.
/// This uses Newton's method with a bisection fallback and converges to ~1e-12.
class PreciseCubic extends Curve {
  const PreciseCubic(this.a, this.b, this.c, this.d);

  final double a;
  final double b;
  final double c;
  final double d;

  static double _bezier(double p1, double p2, double s) {
    final u = 1 - s;
    return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s;
  }

  static double _slope(double p1, double p2, double s) {
    final u = 1 - s;
    return 3 * u * u * p1 + 6 * u * s * (p2 - p1) + 3 * s * s * (1 - p2);
  }

  /// [t] is the time fraction (the curve's x); the result is its y.
  @override
  double transformInternal(double t) {
    // Newton from the identity guess.
    var s = t;
    for (var i = 0; i < 12; i++) {
      final err = _bezier(a, c, s) - t;
      if (err.abs() < 1e-12) return _bezier(b, d, s);
      final slope = _slope(a, c, s);
      if (slope.abs() < 1e-6) break;
      s -= err / slope;
    }
    // Fallback: bisection (x(s) is monotonic for valid control points).
    var lo = 0.0;
    var hi = 1.0;
    s = t;
    for (var i = 0; i < 60; i++) {
      final v = _bezier(a, c, s);
      if ((v - t).abs() < 1e-12) break;
      if (v < t) {
        lo = s;
      } else {
        hi = s;
      }
      s = (lo + hi) / 2;
    }
    return _bezier(b, d, s);
  }
}
