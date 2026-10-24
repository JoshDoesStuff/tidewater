import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/models/album.dart';
import 'shapes/squircle.dart';

/// Placeholder cover art: diagonal gradient with the demo's highlight disc.
/// [squircle] clips to a superellipse with a soft drop shadow; otherwise it
/// fills its box (used behind hero cards, which clip themselves).
class ArtTile extends StatelessWidget {
  const ArtTile({super.key, required this.album, this.size, this.squircle = true});

  final Album album;
  final double? size;
  final bool squircle;

  @override
  Widget build(BuildContext context) {
    final painter = _ArtPainter(
      a: Color(album.colorA),
      b: Color(album.colorB),
      shadow: Theme.of(context).colorScheme.shadow,
      squircle: squircle,
    );
    return RepaintBoundary(
      child: CustomPaint(
        size: size == null ? Size.infinite : Size.square(size!),
        painter: painter,
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter({required this.a, required this.b, required this.shadow, required this.squircle});

  final Color a;
  final Color b;
  final Color shadow;
  final bool squircle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final k = size.width / 112;
    if (squircle) {
      final path = squirclePath(size);
      canvas.drawPath(
        path.shift(Offset(0, 8 * k)),
        Paint()
          ..color = shadow.withValues(alpha: .28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * k),
      );
      canvas.save();
      canvas.clipPath(path);
    }
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
    if (squircle) canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.a != a || old.b != b || old.shadow != shadow || old.squircle != squircle;
}
