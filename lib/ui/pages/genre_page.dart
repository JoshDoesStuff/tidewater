import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/stagger_in.dart';
import '../widgets/expressive_buttons.dart';
import 'page_frame.dart';
import 'widgets/album_card.dart';

/// One genre: Play and Shuffle for its songs, and its albums.
class GenrePage extends ConsumerWidget {
  const GenrePage({super.key, required this.genre});

  final String genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(genreAlbumsProvider(genre));
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final player = ref.read(playbackProvider.notifier);
    final n = albums.value?.length;
    return PageFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GENRE',
              style: text.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: scheme.primary),
            ),
            const SizedBox(height: 6),
            LetterReveal(text: genre, style: text.displaySmall, delay: const Duration(milliseconds: 100)),
            const SizedBox(height: 6),
            Text(
              n == null ? (albums.hasError ? 'Couldn\'t load this genre' : 'Loading…') : '$n album${n == 1 ? '' : 's'}',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ExpressivePillButton(label: 'Play', icon: Icons.play_arrow_rounded, onPressed: () => player.playGenre(genre)),
                ExpressivePillButton(
                  label: 'Shuffle',
                  icon: Icons.shuffle_rounded,
                  glyph: GlyphKind.shuffle,
                  filled: false,
                  onPressed: () => player.playGenre(genre, shuffle: true),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (albums.hasError && !albums.hasValue)
              ErrorPanel(error: albums.error!, onRetry: () => ref.invalidate(genreAlbumsProvider(genre)))
            else if (!albums.hasValue)
              const SkeletonBox(height: 190, radius: 32)
            else if (albums.requireValue.isEmpty)
              const EmptyPanel(icon: Icons.album_rounded, title: 'No albums in this genre')
            else
              Wrap(
                spacing: 26,
                runSpacing: 26,
                children: [
                  for (final (i, a) in albums.requireValue.indexed)
                    StaggerIn(index: i, child: AlbumCard(album: a, size: 156, large: true)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
