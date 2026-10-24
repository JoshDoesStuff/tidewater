import 'package:flutter/material.dart';

/// The only place colors are chosen. Everything else reads
/// `Theme.of(context).colorScheme`.
abstract final class AppTheme {
  /// Seed used until a cover-art scheme exists (milestone 4). Hue of the first
  /// demo album.
  static const seed = Color(0xFFFF7E5F);

  /// Foreground for text/icons drawn directly on top of cover art or a scrim.
  /// Art is not themed, so this is deliberately fixed.
  static const onArt = Color(0xFFFFFFFF);

  static ColorScheme scheme(Brightness brightness, {Color seedColor = seed}) =>
      ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

  static ThemeData build(Brightness brightness, {Color seedColor = seed}) =>
      fromScheme(scheme(brightness, seedColor: seedColor));

  static ThemeData fromScheme(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme
        .copyWith(
          // Page titles ("Good evening", "Library").
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            height: 1.1,
          ),
          // Section headings.
          titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
    );
  }
}
