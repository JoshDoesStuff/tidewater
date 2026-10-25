import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/models/album.dart';
import 'shapes/morph_path.dart';
import 'shapes/morph_shape.dart';

/// Placeholder cover art: diagonal gradient with the demo's highlight disc,
/// filling its box. Real cover art replaces this in milestone 2.
class ArtFill extends StatelessWidget {
  const ArtFill({super.key, required this.album, this.child});

  final Album album;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArtPainter(Color(album.colorA), Color(album.colorB)),
      child: child ?? const SizedBox.expand(),
    );
  }
}

/// Cover art in a [MorphShape]: a squircle that can spring into a scalloped
/// shape ([morph] 0..1) and spin.
class ArtTile extends StatelessWidget {
  const ArtTile({
    super.key,
    required this.album,
    this.size,
    this.params,
    this.morph = 0,
    this.spin = 0,
    this.shadowAlpha = .28,
    this.child,
  });

  final Album album;

  /// Edge length; null fills the available space.
  final double? size;

  /// Shape the tile morphs to. Defaults to the cookie.
  final ShapeParams? params;
  final double morph;
  final double spin;
  final double shadowAlpha;

  /// Painted over the art inside the clip (e.g. a [Ripple]).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tile = MorphShape(
      params: params ?? ShapeKind.cookie.params,
      morph: morph,
      spin: spin,
      shadowAlpha: shadowAlpha,
      child: ArtFill(album: album, child: child),
    );
    return size == null ? tile : SizedBox.square(dimension: size, child: tile);
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.a, this.b);

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ).createShader(rect),
    );
    final d = size.height * .44;
    final c = Offset(size.width * (1 - .12) - d / 2, size.height * .14 + d / 2);
    final ring = (14 * size.width / 156).clamp(4.0, 14.0);
    canvas.drawCircle(c, d / 2 + ring, Paint()..color = AppTheme.onArt.withValues(alpha: .11));
    canvas.drawCircle(c, d / 2, Paint()..color = AppTheme.onArt.withValues(alpha: .2));
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.a != a || old.b != b;
}
