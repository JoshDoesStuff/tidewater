import 'package:flutter/material.dart';

import 'cover_art.dart';
import 'shapes/morph_path.dart';
import 'shapes/morph_shape.dart';

/// Cover art in a [MorphShape]: a squircle that can spring into a scalloped
/// shape ([morph] 0..1) and spin.
class ArtTile extends StatelessWidget {
  const ArtTile({
    super.key,
    required this.coverArt,
    required this.seedKey,
    this.resolution = 300,
    this.size,
    this.params,
    this.exponent = 4.2,
    this.morph = 0,
    this.spin = 0,
    this.shadowAlpha = .28,
    this.child,
  });

  /// Cover-art id and placeholder key; see [CoverArt].
  final String? coverArt;
  final String seedKey;
  final int resolution;

  /// Edge length; null fills the available space.
  final double? size;

  /// Shape the tile morphs to. Defaults to the cookie.
  final ShapeParams? params;

  /// Superellipse exponent of the resting outline (2 is a circle).
  final double exponent;
  final double morph;
  final double spin;
  final double shadowAlpha;

  /// Painted over the art inside the clip (e.g. a [Ripple]).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tile = MorphShape(
      params: params ?? ShapeKind.cookie.params,
      exponent: exponent,
      morph: morph,
      spin: spin,
      shadowAlpha: shadowAlpha,
      child: CoverArt(coverArt: coverArt, seedKey: seedKey, resolution: resolution, child: child),
    );
    return size == null ? tile : SizedBox.square(dimension: size, child: tile);
  }
}
