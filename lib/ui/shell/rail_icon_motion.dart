import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../app/destinations.dart';
import 'code_icons.dart';
import 'home_icon.dart';

/// Sidebar icon artwork. Home, Library and Liked are drawn in code; the rest are
/// Lottie files in `assets/icons/` (credited in Settings). Each plays once when
/// its page is selected and rests on its first frame, which is the whole icon.
abstract final class RailIcons {
  static const _assets = {
    Destination.artists: 'assets/icons/artists.json',
    Destination.lists: 'assets/icons/lists.json',
    Destination.radio: 'assets/icons/radio.json',
    Destination.settings: 'assets/icons/settings.json',
  };

  static final _loading = <String, Future<LottieComposition>>{};

  /// The Lottie composition for [d], loaded once; null for Home.
  static Future<LottieComposition>? load(Destination d) {
    final path = _assets[d];
    return path == null ? null : _loading.putIfAbsent(path, () => AssetLottie(path).load());
  }
}

/// A sidebar icon at animation position [t] (0 to 1). Until the Lottie file
/// loads, the stock Material icon stands in. Artwork is recolored to [color].
Widget railIconMotion(Destination d, double t, Color color, {LottieComposition? composition, double size = 22}) {
  if (d == Destination.home) return HomeIcon(progress: t, color: color, size: size);
  if (d == Destination.liked) return HeartIcon(progress: t, color: color, size: size);
  if (d == Destination.library) return LibraryIcon(progress: t, color: color, size: size);
  if (composition == null) return Icon(d.icon, size: size, color: color);
  // The artwork has padding inside its canvas, so draw it a little larger.
  final box = size * 1.3;
  // A tint over the whole drawing: the files have unnamed shapes, so Lottie's
  // own per-layer color overrides can't address them.
  return ColorFiltered(
    colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
    child: RawLottie(composition: composition, progress: t, width: box, height: box, fit: BoxFit.contain),
  );
}
