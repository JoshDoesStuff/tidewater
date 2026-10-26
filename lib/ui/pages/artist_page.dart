import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/artist.dart';
import '../widgets/art_tile.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/stagger_in.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/shapes/morph_path.dart';
import 'page_frame.dart';
import 'widgets/album_card.dart';

/// An artist: round picture, play and shuffle, and their albums.
class ArtistPage extends ConsumerWidget {
  const ArtistPage({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(artistDetailProvider(artistId));
    return PageFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.hasError && !detail.hasValue)
              ErrorPanel(error: detail.error!, onRetry: () => ref.invalidate(artistDetailProvider(artistId)))
            else if (!detail.hasValue)
              const Row(
                children: [
                  SkeletonBox(width: 180, height: 180, circle: true),
                  SizedBox(width: 28),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 90, height: 12, radius: 6),
                      SizedBox(height: 14),
                      SkeletonBox(width: 300, height: 40, radius: 12),
                    ],
                  ),
                ],
              )
            else
              _ArtistBody(detail: detail.requireValue),
          ],
        ),
      ),
    );
  }
}

class _ArtistBody extends ConsumerWidget {
  const _ArtistBody({required this.detail});

  final ArtistDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = detail.artist;
    final albums = detail.albums;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final player = ref.read(playbackProvider.notifier);
    final reduced = Motion.reduced(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ArtTile(
              coverArt: artist.coverArt,
              seedKey: artist.id,
              resolution: 800,
              size: 180,
              params: ShapeKind.forKey(artist.id).params,
              exponent: 2,
              morph: 0,
              spin: reduced ? 0 : 0,
              shadowAlpha: .4,
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ARTIST',
                    style: text.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: scheme.primary),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: LetterReveal(text: artist.name, style: text.displaySmall, delay: const Duration(milliseconds: 100)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${albums.length} album${albums.length == 1 ? '' : 's'}',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ExpressivePillButton(
                        label: 'Play',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => player.playArtist(artist),
                      ),
                      ExpressivePillButton(
                        label: 'Shuffle',
                        icon: Icons.shuffle_rounded,
              glyph: GlyphKind.shuffle,
                        filled: false,
                        onPressed: () => player.playArtist(artist, shuffle: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Albums', style: text.titleLarge),
        const SizedBox(height: 14),
        if (albums.isEmpty)
          const EmptyPanel(icon: Icons.album_rounded, title: 'No albums')
        else
          Wrap(
            spacing: 26,
            runSpacing: 26,
            children: [
              for (final (i, a) in albums.indexed) StaggerIn(index: i, child: AlbumCard(album: a, size: 156, large: true)),
            ],
          ),
      ],
    );
  }
}
