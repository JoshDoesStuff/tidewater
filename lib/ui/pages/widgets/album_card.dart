import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';
import '../../../core/models/album.dart';
import '../../widgets/art_tile.dart';
import '../../widgets/pressable.dart';

/// Squircle cover with title and artist underneath. Hover morph, play pop-in
/// and tilt arrive in milestone 4.
class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, this.size, this.large = false});

  final Album album;

  /// Cover edge length. Null fills the available width (grid cells).
  final double? size;

  /// Slightly bigger type used in the Library grid.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final card = Pressable(
      onTap: () {}, // Plays the album in milestone 3.
      semanticLabel: '${album.title} by ${album.artist}',
      builder: (context, s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          size != null
              ? _cover(context, s)
              : AspectRatio(aspectRatio: 1, child: _cover(context, s)),
          SizedBox(height: large ? 14 : 12),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(fontSize: large ? 14.5 : 13, fontWeight: FontWeight.w700),
          ),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(fontSize: large ? 12.5 : 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
    return size != null ? SizedBox(width: size, child: card) : card;
  }

  Widget _cover(BuildContext context, PressState s) => AnimatedScale(
        scale: s.pressed ? .94 : 1,
        duration: Motion.of(context, Motion.medium),
        curve: Motion.curve(context, Motion.spring),
        child: ArtTile(album: album, size: size),
      );
}
