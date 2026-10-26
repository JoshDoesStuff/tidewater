import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../core/models/playlist.dart';
import '../widgets/art_tile.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/shapes/morph_path.dart';
import 'page_frame.dart';
import 'widgets/song_row.dart';

/// A playlist: cover, play and shuffle, and its songs.
class PlaylistPage extends ConsumerWidget {
  const PlaylistPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(playlistDetailProvider(playlistId));
    ref.listen(playlistDetailProvider(playlistId), (_, next) {
      next.whenData((d) => ref.read(likedProvider.notifier).seed(d.tracks, addOnly: true));
    });
    return PageFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.hasError && !detail.hasValue)
              ErrorPanel(error: detail.error!, onRetry: () => ref.invalidate(playlistDetailProvider(playlistId)))
            else if (!detail.hasValue)
              Column(
                children: [
                  const SkeletonBox(width: 220, height: 220, radius: 56),
                  const SizedBox(height: 28),
                  for (var i = 0; i < 6; i++) ...[
                    const SkeletonBox(height: 52, radius: 22),
                    const SizedBox(height: 8),
                  ],
                ],
              )
            else
              _Body(detail: detail.requireValue),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final PlaylistDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = detail.playlist;
    final tracks = detail.tracks;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final player = ref.read(playbackProvider.notifier);
    final total = tracks.fold<Duration>(Duration.zero, (a, t) => a + t.duration);
    final minutes = total.inMinutes;
    final length = minutes >= 60 ? '${minutes ~/ 60} hr ${minutes % 60} min' : '$minutes min';

    final cover = ArtTile(
      coverArt: playlist.coverArt,
      seedKey: playlist.id,
      resolution: 800,
      size: 220,
      params: ShapeKind.forKey(playlist.id).params,
      morph: 0,
      spin: 0,
      shadowAlpha: .4,
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playlist.owner == null ? 'PLAYLIST' : 'PLAYLIST · ${playlist.owner}'.toUpperCase(),
          style: text.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: LetterReveal(text: playlist.name, style: text.displaySmall, delay: const Duration(milliseconds: 100)),
        ),
        const SizedBox(height: 6),
        Text(
          '${tracks.length} song${tracks.length == 1 ? '' : 's'} · $length',
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
              onPressed: () => tracks.isEmpty ? null : player.playTracks(tracks),
            ),
            ExpressivePillButton(
              label: 'Shuffle',
              icon: Icons.shuffle_rounded,
              glyph: GlyphKind.shuffle,
              filled: false,
              onPressed: () => tracks.isEmpty ? null : player.playTracks(tracks, shuffle: true),
            ),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [cover, const SizedBox(width: 32), Expanded(child: info)],
              )
            else ...[
              Center(child: cover),
              const SizedBox(height: 20),
              info,
            ],
            const SizedBox(height: 28),
            if (tracks.isEmpty)
              const EmptyPanel(icon: Icons.queue_music_rounded, title: 'This playlist is empty')
            else
              for (final (i, t) in tracks.indexed)
                SizedBox(
                  height: SongRow.height,
                  child: SongRow(track: t, onPlay: () => player.playTracks(tracks, index: i)),
                ),
          ],
        );
      },
    );
  }
}
