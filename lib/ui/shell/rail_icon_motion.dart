import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../app/destinations.dart';
import '../widgets/animated_glyphs.dart';
import 'code_icons.dart';
import 'home_icon.dart';

/// Sidebar icon artwork. Home and Liked are drawn in code; the rest are
/// Lottie files in `assets/icons/` (credited in Settings). Each plays once when
/// its page is selected and rests on its first frame, which is the whole icon.
abstract final class RailIcons {
  static const _assets = {
    Destination.library: 'assets/icons/library.json',
    Destination.artists: 'assets/icons/artists.json',
    Destination.lists: 'assets/icons/lists.json',
    Destination.radio: 'assets/icons/radio.json',
    Destination.settings: 'assets/icons/settings.json',
  };

  /// The Lottie composition for [d], loaded once; null for Home.
  static Future<LottieComposition>? load(Destination d) {
    final path = _assets[d];
    return path == null ? null : IconComposition.load(path);
  }
}

/// A sidebar icon at animation position [t] (0 to 1). Until the Lottie file
/// loads, the stock Material icon stands in. Artwork is recolored to [color].
Widget railIconMotion(Destination d, double t, Color color, {LottieComposition? composition, double size = 22}) {
  if (d == Destination.home) return HomeIcon(progress: t, color: color, size: size);
  if (d == Destination.liked) return HeartIcon(progress: t, color: color, size: size);
  if (composition == null) return Icon(d.icon, size: size, color: color);
  // The artwork has padding inside its canvas, so draw it a little larger.
  final box = size * 1.3;
  // A tint over the whole drawing: the files have unnamed shapes, so Lottie's
  // own per-layer color overrides can't address them.
  Widget art = RawLottie(composition: composition, progress: t, width: box, height: box, fit: BoxFit.contain);
  // The gear's file only nudges it, so it turns a clear half revolution here
  // (its teeth repeat every 45 degrees, so it lands looking unchanged).
  if (d == Destination.settings) {
    art = Transform.rotate(angle: math.pi * Curves.easeOutCubic.transform((t / .7).clamp(0.0, 1.0)), child: art);
  }
  return ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcATop), child: art);
}
