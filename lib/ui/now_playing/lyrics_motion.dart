import 'package:flutter/animation.dart';

import '../../app/theme/motion.dart';

/// Sizing/dimming recipe for the lyrics list, taken from the demo's CSS.
/// [card] is `.ll` (the lyrics card); [idle] is `.il` (big list beside the
/// cover in idle mode).
class LyricsStyle {
  const LyricsStyle({
    required this.fontSize,
    required this.lineHeight,
    required this.activeScale,
    required this.nearScale,
    required this.farScale,
    required this.spacing,
    required this.nearOpacity,
    required this.midOpacity,
    required this.nearBlur,
    required this.midBlur,
    required this.farBlur,
    required this.fade,
    required this.anchorY,
    required this.anchorFrac,
  });

  final double fontSize;

  /// CSS `line-height` multiplier, or null for the font's default.
  final double? lineHeight;
  final double activeScale;
  final double nearScale; // distance 1
  final double farScale; // distance 2 and beyond
  final double spacing; // margin-bottom between lines
  final double nearOpacity; // distance 1
  final double midOpacity; // distance 2
  final double nearBlur;
  final double midBlur;
  final double farBlur; // distance 3 and beyond

  /// Fraction of the height faded at each edge (the CSS mask).
  final double fade;

  /// Where the active line sits inside the list box (CSS `translateY` anchor):
  /// the list is moved so `top + height * anchorFrac` of the active line lands
  /// on [anchorY]. Card: 52 and .5. Idle: 220 and .64.
  final double anchorY;
  final double anchorFrac;

  static const card = LyricsStyle(
    fontSize: 22,
    lineHeight: null,
    activeScale: 1.3,
    nearScale: 1,
    farScale: .92,
    spacing: 12,
    nearOpacity: .45,
    midOpacity: .25,
    nearBlur: .8,
    midBlur: 1.5,
    farBlur: 2,
    fade: .25,
    anchorY: 52,
    anchorFrac: .5,
  );

  static const idle = LyricsStyle(
    fontSize: 36,
    lineHeight: 1.18,
    activeScale: 1.28,
    nearScale: .95,
    farScale: .86,
    spacing: 26,
    nearOpacity: .5,
    midOpacity: .28,
    nearBlur: 1,
    midBlur: 2,
    farBlur: 3,
    fade: .22,
    anchorY: 220,
    anchorFrac: .64,
  );
}

/// What a line should look like at [distance] lines from the active one
/// (CSS classes `d0`, `d1`, `d2`, none).
class LineTarget {
  const LineTarget({required this.opacity, required this.blur, required this.scale, required this.accent});

  final double opacity;
  final double blur;
  final double scale;

  /// 1 = accent (primary) color, 0 = normal text color.
  final double accent;
}

LineTarget lineTarget(int distance, LyricsStyle s) => switch (distance) {
      0 => LineTarget(opacity: 1, blur: 0, scale: s.activeScale, accent: 1),
      1 => LineTarget(opacity: s.nearOpacity, blur: s.nearBlur, scale: s.nearScale, accent: 0),
      2 => LineTarget(opacity: s.midOpacity, blur: s.midBlur, scale: s.farScale, accent: 0),
      _ => LineTarget(opacity: .2, blur: s.farBlur, scale: s.farScale, accent: 0),
    };

/// How far to translate the list so the active line is where the CSS puts it.
double listOffsetFor({required double lineTop, required double lineHeight, required LyricsStyle style}) =>
    style.anchorY - (lineTop + lineHeight * style.anchorFrac);

/// The CSS transition durations and curves from the demo.
abstract final class LyricTiming {
  static const opacity = Duration(milliseconds: 800); // .8s var(--emph)
  static const blur = Duration(milliseconds: 800); // filter .8s var(--emph)
  static const scale = Duration(milliseconds: 900); // transform .9s var(--emph)
  static const color = Duration(milliseconds: 600); // color .6s (default `ease`)
  static const slide = Duration(milliseconds: 900); // .in transform .9s var(--emph)

  static const emphasized = Motion.emphasized;
  static const colorCurve = Motion.cssEase;
}

/// A CSS transition on one number: when the target changes it starts from the
/// value currently shown, over the full duration, so changing the target in
/// the middle never jumps.
class CssTransition {
  CssTransition(double value)
      : _from = value,
        _to = value;

  double _from;
  double _to;
  Duration _start = Duration.zero;
  Duration _duration = Duration.zero;
  Curve _curve = Curves.linear;

  double get target => _to;

  double at(Duration now) {
    if (_duration == Duration.zero) return _to;
    final t = ((now - _start).inMicroseconds / _duration.inMicroseconds).clamp(0.0, 1.0);
    return _from + (_to - _from) * _curve.transform(t);
  }

  bool isActive(Duration now) => _duration != Duration.zero && now - _start < _duration;

  /// Heads to [target] over [duration]. No-op if it is already the target.
  void retarget(double target, Duration now, Duration duration, Curve curve) {
    if (target == _to) return;
    _from = at(now);
    _to = target;
    _start = now;
    _duration = duration;
    _curve = curve;
  }

  /// Jumps to [value] with no transition.
  void snap(double value) {
    _from = value;
    _to = value;
    _duration = Duration.zero;
  }
}
