import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single source of motion timings and curves. Never inline durations.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 520);

  static const standard = Cubic(.2, 0, 0, 1);
  static const emphasized = Cubic(.05, .7, .1, 1);
  static const spring = Cubic(.34, 1.56, .64, 1);

  /// True when the system or the Settings toggle asks for reduced motion.
  /// The app root folds the toggle into `MediaQuery.disableAnimations`.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  /// [d] unless motion is reduced, in which case the change is instant.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;

  /// [curve] unless motion is reduced, in which case no overshoot is allowed.
  static Curve curve(BuildContext context, Curve curve) => reduced(context) ? Curves.linear : curve;
}

/// Settings toggle for reduced motion (persisted in a later milestone).
class ReduceMotionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final reduceMotionProvider = NotifierProvider<ReduceMotionNotifier, bool>(ReduceMotionNotifier.new);
