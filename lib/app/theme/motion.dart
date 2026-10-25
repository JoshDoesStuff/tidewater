import 'package:flutter/material.dart';

import 'precise_cubic.dart';

/// Single source of motion timings and curves. Never inline durations.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 520);

  /// Scheme crossfade when the playing album changes.
  static const recolor = Duration(milliseconds: 800);

  // Solved exactly (see [PreciseCubic]); Flutter's own Cubic is noisy by up to
  // ~0.4 % of the range per frame, which shows as jitter on big movements.
  static const standard = PreciseCubic(.2, 0, 0, 1);
  static const emphasized = PreciseCubic(.05, .7, .1, 1);
  static const spring = PreciseCubic(.34, 1.56, .64, 1);

  /// CSS `ease-in` / `ease-in-cubic` equivalents for exits (letters dropping away).
  static const exitMotion = PreciseCubic(.55, .055, .675, .19);
  static const exitFade = PreciseCubic(.42, 0, 1, 1);

  /// True when the system or the Settings toggle asks for reduced motion.
  /// The app root folds the toggle into `MediaQuery.disableAnimations`.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  /// [d] unless motion is reduced, in which case the change is instant.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;

  /// [curve] unless motion is reduced, in which case no overshoot is allowed.
  static Curve curve(BuildContext context, Curve curve) => reduced(context) ? Curves.linear : curve;
}
