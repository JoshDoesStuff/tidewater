import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../core/models/track.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/stagger_in.dart';
import 'page_frame.dart';
import 'widgets/album_card.dart';
import 'widgets/song_row.dart';
import 'widgets/view_toggle.dart';

/// Hearted songs, as a list or as cards (the choice is remembered).
class LikedPage extends ConsumerWidget {
  const LikedPage({super.key});

  static const _gap = 26.0;
  static const _cardWidth = 156.0;
  static const _pad = EdgeInsets.fromLTRB(24, 0, 40, PageFrame.bottomClearance);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cards = ref.watch(likedAsCardsProvider);
    final fetched = ref.watch(likedSongsProvider);
    final liked = ref.watch(likedProvider);
    final List<Track>? songs = fetched.hasValue
        ? [
            for (final t in fetched.requireValue)
              if (liked.contains(t.id)) t,
          ]
        : null;
    final n = songs?.length;
    final subtitle = n == null
        ? (fetched.hasError ? "Couldn't load liked songs" : 'Loading…')
        : '$n song${n == 1 ? '' : 's'}';

    return PageFrame(
      child: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(700),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 36, 40, 22),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LetterReveal(
                          text: 'Liked songs',
                          style: text.displaySmall,
                          delay: const Duration(milliseconds: 100),
                        ),
                        Text(
                          subtitle,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ViewToggle(
                    cards: cards,
                    onChanged: ref.read(likedAsCardsProvider.notifier).set,
                  ),
                ],
              ),
            ),
          ),
          ..._body(ref, fetched, songs, cards),
        ],
      ),
    );
  }

  List<Widget> _body(
    WidgetRef ref,
    AsyncValue<List<Track>> fetched,
    List<Track>? songs,
    bool cards,
  ) {
    if (fetched.hasError && !fetched.hasValue) {
      return [
        SliverPadding(
          padding: _pad,
          sliver: SliverToBoxAdapter(
            child: ErrorPanel(error: fetched.error!, onRetry: () => ref.invalidate(likedSongsProvider)),
          ),
        ),
      ];
    }
    if (songs == null) {
      return [
        SliverPadding(
          padding: _pad,
          sliver: SliverList.builder(
            itemCount: 8,
            itemBuilder: (_, _) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SkeletonBox(height: 52, radius: 22),
            ),
          ),
        ),
      ];
    }
    if (songs.isEmpty) {
      return [
        const SliverPadding(
          padding: _pad,
          sliver: SliverToBoxAdapter(
            child: EmptyPanel(
              icon: Icons.favorite_rounded,
              title: 'No liked songs yet',
              message: 'Tap the heart on a song and it shows up here.',
            ),
          ),
        ),
      ];
    }
    if (cards) {
      return [
        SliverPadding(
          padding: _pad,
          sliver: SliverLayoutBuilder(
            builder: (context, c) {
              final columns = ((c.crossAxisExtent + _gap) / (_cardWidth + _gap)).floor().clamp(2, 12);
              final tile = (c.crossAxisExtent - (columns - 1) * _gap) / columns;
              return SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: _gap,
                  crossAxisSpacing: _gap,
                  mainAxisExtent: tile + 14 + 40,
                ),
                itemCount: songs.length,
                itemBuilder: (context, i) => StaggerIn(
                  key: ValueKey(songs[i].id),
                  index: i < 24 ? i : 0,
                  child: TrackCard(tracks: songs, index: i, large: true),
                ),
              );
            },
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: _pad,
        sliver: SliverFixedExtentList(
          itemExtent: SongRow.height,
          delegate: SliverChildBuilderDelegate(
            (context, i) => StaggerIn(
              key: ValueKey(songs[i].id),
              index: i < 12 ? i : 0,
              child: SongRow(
                track: songs[i],
                onPlay: () => ref.read(playbackProvider.notifier).playTracks(songs, index: i),
              ),
            ),
            childCount: songs.length,
          ),
        ),
      ),
    ];
  }
}

