import 'package:flutter/material.dart';

import '../../core/color/cover_seed.dart';
import 'app_theme.dart';

/// Material color science for an album: a full [ColorScheme] generated from
/// the cover's seed color (see `seedFromPixels`), cached per seed and
/// brightness.
abstract final class AlbumScheme {
  static final _cache = <(CoverSeed, Brightness), ColorScheme>{};

  static ColorScheme of(CoverSeed? seed, Brightness brightness) {
    if (seed == null) return AppTheme.scheme(brightness);
    return _cache.putIfAbsent(
      (seed, brightness),
      () => AppTheme.scheme(brightness, seedColor: Color(seed.argb), muted: seed.muted),
    );
  }
}

/// Interpolates whole schemes so the app recolors smoothly.
///
/// The fade moves in [steps] steps (about every 20 ms over the 800 ms recolor,
/// ~50 Hz) instead of on every frame. A color fade that fine-grained is
/// invisible, but each new scheme rebuilds a whole `ThemeData` and every
/// widget that reads it: on a 180 Hz display that was 144 rebuilds per recolor
/// and a build time (4.7 ms p90) close to the whole frame budget. The same
/// scheme object is returned for every frame inside a step, so listeners of
/// the theme are told once per step, not once per frame.
class ColorSchemeTween extends Tween<ColorScheme> {
  ColorSchemeTween({super.begin, super.end});

  static const steps = 40;

  ColorScheme? _begin;
  ColorScheme? _end;
  int _step = -1;
  ColorScheme? _scheme;

  @override
  ColorScheme lerp(double t) {
    final step = (t * steps).floor().clamp(0, steps);
    final cached = _scheme;
    if (cached != null && step == _step && identical(_begin, begin) && identical(_end, end)) return cached;
    _begin = begin;
    _end = end;
    _step = step;
    return _scheme = ColorScheme.lerp(begin!, end!, step / steps);
  }
}

/// Builds the `ThemeData` for a scheme once and reuses it while the scheme is
/// the same object (see [ColorSchemeTween]).
class ThemeMemo {
  ColorScheme? _scheme;
  ThemeData? _data;

  ThemeData of(ColorScheme scheme, ThemeData Function(ColorScheme) build) {
    if (!identical(scheme, _scheme)) {
      _scheme = scheme;
      _data = build(scheme);
    }
    return _data!;
  }
}
