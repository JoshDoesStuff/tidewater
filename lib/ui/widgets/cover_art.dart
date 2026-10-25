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
  const CoverArt({super.key, required this.coverArt, required this.seedKey, this.resolution = 300, this.child});

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
        if (id != null)
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

(Color, Color) _computePlaceholderColors(String key) {
  final hue = Hct.fromInt(CoverSeed.fromKey(key).argb).hue;
  return (Color(Hct.from(hue, 52, 62).toInt()), Color(Hct.from((hue + 48) % 360, 48, 30).toInt()));
}

/// Diagonal gradient with the demo's highlight disc.
class _PlaceholderPainter extends CustomPainter {
  _PlaceholderPainter(this.key);

  final String key;

  @override
  void paint(Canvas canvas, Size size) {
    final (a, b) = placeholderColors(key);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]).createShader(rect),
    );
    final d = size.height * .44;
    final c = Offset(size.width * (1 - .12) - d / 2, size.height * .14 + d / 2);
    final ring = (14 * size.width / 156).clamp(4.0, 14.0);
    canvas.drawCircle(c, d / 2 + ring, Paint()..color = AppTheme.onArt.withValues(alpha: .11));
    canvas.drawCircle(c, d / 2, Paint()..color = AppTheme.onArt.withValues(alpha: .2));
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) => old.key != key;
}
