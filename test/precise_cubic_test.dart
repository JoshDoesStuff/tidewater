import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/theme/motion.dart';
import 'package:tidewater/app/theme/precise_cubic.dart';

/// Reference solved by plain bisection to machine precision.
double _reference(double a, double b, double c, double d, double x) {
  double bez(double p1, double p2, double s) {
    final u = 1 - s;
    return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s;
  }

  var lo = 0.0;
  var hi = 1.0;
  for (var i = 0; i < 100; i++) {
    final mid = (lo + hi) / 2;
    if (bez(a, c, mid) < x) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return bez(b, d, (lo + hi) / 2);
}

void main() {
  const tokens = {
    'spring': (.34, 1.56, .64, 1.0),
    'emphasized': (.05, .7, .1, 1.0),
    'standard': (.2, 0.0, 0.0, 1.0),
    'exitMotion': (.55, .055, .675, .19),
    'exitFade': (.42, 0.0, 1.0, 1.0),
  };
  const curves = {
    'spring': Motion.spring,
    'emphasized': Motion.emphasized,
    'standard': Motion.standard,
    'exitMotion': Motion.exitMotion,
    'exitFade': Motion.exitFade,
  };

  for (final name in tokens.keys) {
    test('$name matches the exact CSS cubic-bezier', () {
      final (a, b, c, d) = tokens[name]!;
      final curve = curves[name]!;
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      for (var i = 1; i < 2000; i++) {
        final x = i / 2000;
        expect(curve.transform(x), closeTo(_reference(a, b, c, d, x), 1e-9), reason: '$name at $x');
      }
    });
  }

  test('spring has no frame-to-frame noise (Flutter\'s Cubic does)', () {
    // 720 ms at 60 fps = 43 frames. Second difference of the error against the
    // exact curve: this noise is what shows as jitter on a 58 px title.
    double worst(Curve curve) {
      final err = [for (var k = 0; k <= 43; k++) curve.transform(k / 43) - _reference(.34, 1.56, .64, 1, k / 43)];
      var w = 0.0;
      for (var k = 2; k < err.length; k++) {
        w = math.max(w, (err[k] - 2 * err[k - 1] + err[k - 2]).abs());
      }
      return w;
    }

    final precise = worst(const PreciseCubic(.34, 1.56, .64, 1));
    final flutter = worst(const Cubic(.34, 1.56, .64, 1));
    expect(precise * .65 * 58, lessThan(.0001), reason: 'precise noise in px');
    expect(flutter * .65 * 58, greaterThan(.05), reason: 'documents why PreciseCubic exists');
  });
}
