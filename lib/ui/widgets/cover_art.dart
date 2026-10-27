import '../../app/perf_flags.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart' show Hct;

import '../../app/providers/cover_providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/motion.dart';
import '../../core/api/cover_cache.dart';
import '../../core/color/cover_seed.dart';

/// Cover art from the disk cache, falling back to the network. Flutter's
/// `ImageCache` keeps decoded images in memory by this key.
@immutable
class CoverImage extends ImageProvider<CoverImage> {
  const CoverImage(this.cache, this.coverArt, this.size);

  final CoverStore cache;
  final String coverArt;
  final int size;

  @override
  Future<CoverImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CoverImage key, ImageDecoderCallback decode) => MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: 1,
        debugLabel: 'cover $coverArt@$size',
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await cache.get(coverArt, size: size);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is CoverImage && identical(other.cache, cache) && other.coverArt == coverArt && other.size == size;

  @override
  int get hashCode => Object.hash(identityHashCode(cache), coverArt, size);
}

/// A cover filling its box. While the image loads (or if the album has none)
/// it shows a gradient picked from [seedKey], then fades the art in over it.
///
/// Once the image is fully in, the gradient is dropped from the tree: painted
/// underneath every loaded cover it cost ~10 ms of raster time per frame on a
/// grid of 25 tiles (measured on real data), for nothing anyone can see.
class CoverArt extends ConsumerStatefulWidget {
  const CoverArt({
    super.key,
    required this.coverArt,
    required this.seedKey,
    this.resolution = 300,
    this.child,
  });

  /// Cover-art id from the server, or null.
  final String? coverArt;

  /// Stable id (usually the album id) that picks the placeholder colors.
  final String seedKey;

  /// Pixel size requested from the server: 300 for grids, 800 for Now Playing.
  final int resolution;
  final Widget? child;

  @override
  ConsumerState<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends ConsumerState<CoverArt> with SingleTickerProviderStateMixin {
  /// 0 -> 1 as the image fades in. Drawn as the image's own alpha: wrapping it
  /// in an opacity layer made every tile that was fading in an offscreen pass.
  late final AnimationController _fade = AnimationController(vsync: this);
  /// The image is completely opaque over the whole box.
  bool _covered = false;
  Timer? _timer;

  @override
  void didUpdateWidget(CoverArt old) {
    super.didUpdateWidget(old);
    if (old.coverArt != widget.coverArt) {
      // A different cover: until it arrives the old image (or nothing) shows.
      _timer?.cancel();
      _timer = null;
      _covered = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _coverAfter(Duration fade) {
    if (_covered || _timer != null) return;
    _timer = Timer(fade + const Duration(milliseconds: 60), () {
      _timer = null;
      if (mounted) setState(() => _covered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.coverArt;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_covered) CustomPaint(painter: _PlaceholderPainter(widget.seedKey)),
        if (id != null && PerfFlags.instance.covers)
          Image(
            image: CoverImage(ref.watch(coverCacheProvider), id, widget.resolution),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
            opacity: _fade,
            frameBuilder: (context, image, frame, sync) {
              final fade = sync ? Duration.zero : Motion.of(context, Motion.medium);
              if (frame != null) {
                if (fade == Duration.zero) {
                  _fade.value = 1;
                } else if (_fade.value == 0 && !_fade.isAnimating) {
                  _fade.animateTo(1, duration: fade, curve: Curves.linear);
                }
                _coverAfter(fade);
              }
              return image;
            },
          ),
        widget.child ?? const SizedBox.expand(),
      ],
    );
  }
}

/// The placeholder gradient's two colors for [key]. Also used in tests.
final _placeholderCache = <String, (Color, Color)>{};

(Color, Color) placeholderColors(String key) => _placeholderCache.putIfAbsent(key, () => _computePlaceholderColors(key));

/// Stable across launches (String.hashCode is not promised to be).
int _hash(String key) {
  var h = 0x811c9dc5;
  for (final c in key.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

const _hueShifts = [48.0, -52.0, 150.0, 24.0, -120.0, 90.0];

(Color, Color) _computePlaceholderColors(String key) {
  final h = _hash(key);
  final hue = Hct.fromInt(CoverSeed.fromKey(key).argb).hue;
  final shift = _hueShifts[(h >> 3) % _hueShifts.length];
  final chroma = 40.0 + (h >> 7) % 22;
  final tone = 56.0 + (h >> 11) % 14;
  return (
    Color(Hct.from(hue, chroma + 6, tone).toInt()),
    Color(Hct.from((hue + shift + 360) % 360, chroma, 24.0 + (h >> 15) % 14).toInt()),
  );
}

const _gradientEnds = [
  (Alignment.topLeft, Alignment.bottomRight),
  (Alignment.topRight, Alignment.bottomLeft),
  (Alignment.topCenter, Alignment.bottomCenter),
  (Alignment.centerLeft, Alignment.centerRight),
];

/// Gradient with one of several cheap decorations (picked from the key, so
/// neighbors differ), and the [label]'s initials when there is one.
class _PlaceholderPainter extends CustomPainter {
  _PlaceholderPainter(this.key);

  final String key;

  @override
  void paint(Canvas canvas, Size size) {
    final (a, b) = placeholderColors(key);
    final h = _hash(key);
    final rect = Offset.zero & size;
    final (begin, end) = _gradientEnds[h % _gradientEnds.length];
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: begin, end: end, colors: [a, b]).createShader(rect));
    final soft = Paint()..color = AppTheme.onArt.withValues(alpha: .11);
    final mid = Paint()..color = AppTheme.onArt.withValues(alpha: .2);
    final w = size.width;
    final hgt = size.height;
    switch ((h >> 5) % 5) {
      case 0: // highlight disc, top right (the demo's)
        final d = hgt * .44;
        final c = Offset(w * .88 - d / 2, hgt * .14 + d / 2);
        final ring = (14 * w / 156).clamp(4.0, 14.0);
        canvas.drawCircle(c, d / 2 + ring, soft);
        canvas.drawCircle(c, d / 2, mid);
      case 1: // two overlapping discs, bottom left
        canvas.drawCircle(Offset(w * .28, hgt * .78), hgt * .36, soft);
        canvas.drawCircle(Offset(w * .46, hgt * .9), hgt * .26, mid);
      case 2: // diagonal bands
        final band = Paint()
          ..color = AppTheme.onArt.withValues(alpha: .1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .09;
        final path = Path();
        for (var i = -1; i < 4; i++) {
          final x = w * (.15 + i * .28);
          path
            ..moveTo(x, hgt)
            ..lineTo(x + w * .5, 0);
        }
        canvas.drawPath(path, band);
      case 3: // concentric rings, centered
        final c = Offset(w / 2, hgt / 2);
        canvas.drawCircle(c, hgt * .46, soft);
        canvas.drawCircle(c, hgt * .32, soft);
        canvas.drawCircle(c, hgt * .18, mid);
      default: // half moon rising from the bottom
        canvas.drawCircle(Offset(w * .5, hgt * 1.02), hgt * .52, soft);
        canvas.drawCircle(Offset(w * .5, hgt * 1.02), hgt * .34, mid);
    }
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) => old.key != key;
}
