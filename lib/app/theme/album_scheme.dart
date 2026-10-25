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
class ColorSchemeTween extends Tween<ColorScheme> {
  ColorSchemeTween({super.begin, super.end});

  @override
  ColorScheme lerp(double t) => ColorScheme.lerp(begin!, end!, t);
}
