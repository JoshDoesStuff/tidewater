import 'package:flutter/material.dart';

/// The only place colors are chosen. Everything else reads
/// `Theme.of(context).colorScheme`.
abstract final class AppTheme {
  /// Seed used until the first album plays and its cover colors take over.
  static const seed = Color(0xFFFF7E5F);

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
