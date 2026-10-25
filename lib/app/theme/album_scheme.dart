import 'package:flutter/material.dart';

import '../../core/models/album.dart';
import 'app_theme.dart';

/// Material color science for an album: a full [ColorScheme] generated from
/// the album's dominant color, cached per album id and brightness.
///
/// With real cover art (milestone 2+) the seed comes from
/// `QuantizerCelebi` + `Score`; until then the placeholder gradient's first
/// color stands in for it.
abstract final class AlbumScheme {
  static final _cache = <(String, Brightness), ColorScheme>{};

  static ColorScheme of(Album? album, Brightness brightness) {
    if (album == null) return AppTheme.scheme(brightness);
    return _cache.putIfAbsent(
      (album.id, brightness),
      () => AppTheme.scheme(brightness, seedColor: Color(album.colorA)),
    );
  }
}

/// Interpolates whole schemes so the app recolors smoothly.
class ColorSchemeTween extends Tween<ColorScheme> {
  ColorSchemeTween({super.begin, super.end});

  @override
  ColorScheme lerp(double t) => ColorScheme.lerp(begin!, end!, t);
}
