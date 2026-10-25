import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/playback_providers.dart';
import '../../../app/theme/motion.dart';
import '../../../core/data/fake_library.dart';
import '../../widgets/art_tile.dart';
import '../../widgets/effects/eq_bars.dart';
import '../../widgets/effects/ripple.dart';
import '../../widgets/shapes/morph_path.dart';

/// Squircle cover with title and artist underneath.
///
/// Hover lifts the card, morphs the tile into its scalloped shape (assigned
/// by [index]), pops in a play button and tilts toward the cursor. Press
/// scales it down. The playing album stays morphed, slowly spins and shows
/// the EQ badge.
class AlbumCard extends ConsumerStatefulWidget {
  const AlbumCard({super.key, required this.index, this.size, this.large = false});

  /// Index into the library (also selects the shape).
  final int index;

  /// Cover edge length. Null fills the available width (grid cells).
  final double? size;

  /// Slightly bigger type used in the Library grid.
  final bool large;

  @override
  ConsumerState<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends ConsumerState<AlbumCard> {
  static const _maxTiltDeg = 6.0;

  bool _hovered = false;
  bool _pressed = false;
  Offset _tilt = Offset.zero; // x: rotateY, y: rotateX (radians)

  void _onHover(PointerEvent e, Size size) {
    final px = (e.localPosition.dx / size.width - .5).clamp(-.5, .5);
    final py = (e.localPosition.dy / size.height - .5).clamp(-.5, .5);
    const k = _maxTiltDeg * 2 * 0.0174533; // ±.5 → ±6°
    setState(() => _tilt = Offset(px * k, -py * k));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final album = fakeAlbums[widget.index];
    final active = ref.watch(activeAlbumIndexProvider) == widget.index;
    final playing = active && ref.watch(playbackProvider.select((s) => s.playing));
    final reduced = Motion.reduced(context);
    final shape = ShapeKind.forIndex(widget.index).params;
    final morphed = _hovered || active;

    final cover = LayoutBuilder(
      builder: (context, box) {
        final tileSize = Size(box.maxWidth, box.maxWidth);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
            _tilt = Offset.zero;
          }),
          onHover: (e) => _onHover(e, tileSize),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () => ref.read(playbackProvider.notifier).playIndex(widget.index),
            child: TweenAnimationBuilder<_Pose>(
              tween: _PoseTween(end: _Pose(tilt: reduced ? Offset.zero : _tilt, lift: _hovered && !reduced ? -4 : 0, scale: _pressed ? .94 : 1)),
              duration: reduced ? Duration.zero : (_hovered && !_pressed ? Motion.fast : Motion.medium),
              curve: reduced ? Curves.linear : (_hovered && !_pressed ? Motion.standard : Motion.spring),
              builder: (context, pose, child) => Transform(
                alignment: Alignment.center,
                transform: (Matrix4.identity()
                  ..setEntry(3, 2, 1 / 520)
                  ..translateByDouble(0, pose.lift, 0, 1)
                  ..rotateX(pose.tilt.dy)
                  ..rotateY(pose.tilt.dx)
                  ..scaleByDouble(pose.scale, pose.scale, 1, 1)),
                child: child,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ArtTile(
                      album: album,
                      params: shape,
                      morph: morphed ? 1 : 0,
                      spin: active && !reduced ? .72 : 0,
                      child: Ripple(color: scheme.onPrimary, child: const SizedBox.expand()),
                    ),
                  ),
                  if (active)
                    Positioned.fill(
                      child: IgnorePointer(child: Center(child: EqBadge(animating: playing))),
                    ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: _PlayPop(visible: _hovered && !active),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cover,
        SizedBox(height: widget.large ? 14 : 12),
        Text(
          album.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(
            fontSize: widget.large ? 14.5 : 13,
            fontWeight: FontWeight.w700,
            color: active ? scheme.primary : scheme.onSurface,
          ),
        ),
        Text(
          album.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(fontSize: widget.large ? 12.5 : 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
    return widget.size != null ? SizedBox(width: widget.size, child: card) : card;
  }
}

/// Hover play button: pops in with scale + untilt on the spring curve and
/// squares off a little.
class _PlayPop extends StatelessWidget {
  const _PlayPop({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Motion.of(context, Motion.slow);
    final c = Motion.curve(context, Motion.spring);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Motion.of(context, Motion.medium),
        child: AnimatedScale(
          scale: visible ? 1 : .3,
          duration: d,
          curve: c,
          child: AnimatedRotation(
            turns: visible ? 0 : -.111,
            duration: d,
            curve: c,
            child: AnimatedContainer(
              duration: d,
              curve: c,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(visible ? 16 : 23),
                boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Icon(Icons.play_arrow_rounded, size: 24, color: scheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pose {
  const _Pose({required this.tilt, required this.lift, required this.scale});

  final Offset tilt;
  final double lift;
  final double scale;
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({super.end});

  @override
  _Pose lerp(double t) {
    final a = begin ?? end!;
    final b = end!;
    return _Pose(
      tilt: Offset.lerp(a.tilt, b.tilt, t)!,
      lift: a.lift + (b.lift - a.lift) * t,
      scale: a.scale + (b.scale - a.scale) * t,
    );
  }
}
