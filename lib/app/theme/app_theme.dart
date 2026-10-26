import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

/// The only place colors are chosen. Everything else reads
/// `Theme.of(context).colorScheme`.
abstract final class AppTheme {
  /// Seed used until the first album plays and its cover colors take over.
  static const seed = Color(0xFFFF7E5F);

  /// The blue of the Tidewater icon and banner; the sign-in screen is themed
  /// from it before any album colors exist ([seed] is the icon's coral).
  static const brandBlue = Color(0xFF1B57B8);

  /// The flat Tidewater artwork (icon, banner, sign-in scene) uses these exact
  /// colors rather than the album-driven scheme.
  static const brandLine = Color(0xFFD7F2FF);
  static const brandGroove1 = Color(0xFF86ADE6);
  static const brandGroove2 = Color(0xFF5F8DD6);
  static const brandShine = Color(0xFFB5CFF3);
  static const brandWater = Color(0xFF3F9BEE);
  static const brandWaterLine = Color(0xFF7CC4FF);
  static const brandSurface = Color(0xFFE4F7FF);
  static const brandHole = Color(0xFF123A72);
  static const brandSail = Color(0xFFF4FBFF);

  /// Foreground for text/icons drawn directly on top of cover art or a scrim.
  /// Art is not themed, so this is deliberately fixed.
  static const onArt = Color(0xFFFFFFFF);

  /// [muted] is for art with no real color (gray, black-and-white): a neutral
  /// scheme instead of one tinted by an arbitrary hue.
  static ColorScheme scheme(Brightness brightness, {Color seedColor = seed, bool muted = false}) => ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        dynamicSchemeVariant: muted ? DynamicSchemeVariant.neutral : DynamicSchemeVariant.tonalSpot,
      );

  static ThemeData build(Brightness brightness, {Color seedColor = seed, bool muted = false}) =>
      fromScheme(scheme(brightness, seedColor: seedColor, muted: muted));

  static const fontFamily = 'GoogleSansFlex';

  /// A style with the font's roundness axis fully on and the given width:
  /// Material 3 Expressive uses variable width and roundness for emphasis.
  static TextStyle? _round(
    TextStyle? s, {
    required double wdth,
    double? size,
    FontWeight? weight,
    double? tracking,
    double? height,
  }) =>
      s?.copyWith(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: height,
        fontVariations: [FontVariation('ROND', 100), FontVariation('wdth', wdth)],
      );

  /// For text that is the user's music (track, album, artist names), which is
  /// often Japanese or Chinese: the platform's own font, which has those
  /// glyphs and matches the fallback, instead of Google Sans Flex.
  static TextStyle? content(TextStyle? s) => s?.copyWith(
        fontFamily: Typography.material2021(platform: defaultTargetPlatform).black.bodyLarge?.fontFamily,
        fontVariations: const [],
      );

  static ThemeData fromScheme(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final t = base.textTheme;
    final text = t
        .copyWith(
          // Page titles ("Good evening", "Library"): heavy, wide and round.
          displaySmall: _round(t.displaySmall, wdth: 118, size: 44, weight: FontWeight.w700, tracking: -.5, height: 1.1),
          headlineMedium: _round(t.headlineMedium, wdth: 114, weight: FontWeight.w700),
          headlineSmall: _round(t.headlineSmall, wdth: 112, weight: FontWeight.w700),
          // Section headings.
          titleLarge: _round(t.titleLarge, wdth: 110, size: 22, weight: FontWeight.w700),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
    );
  }
}
