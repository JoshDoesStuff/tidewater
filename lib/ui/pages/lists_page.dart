import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../core/models/playlist.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/stagger_in.dart';
import 'page_frame.dart';
import 'widgets/album_card.dart';

/// Playlists as a grid of cards.
class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});

  static const _gap = 26.0;
  static const _cardWidth = 156.0;
  static const _pad = EdgeInsets.fromLTRB(24, 0, 40, PageFrame.bottomClearance);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final playlists = ref.watch(playlistsProvider);
    final n = playlists.value?.length;
    final subtitle = n == null
        ? (playlists.hasError ? "Couldn't load playlists" : 'Loading…')
        : '$n playlist${n == 1 ? '' : 's'}';

    return PageFrame(
      child: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(700),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 36, 40, 22),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LetterReveal(
                    text: 'Playlists',
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
          ),
          SliverPadding(padding: _pad, sliver: _content(ref, playlists)),
        ],
      ),
    );
  }

  Widget _content(WidgetRef ref, AsyncValue<List<Playlist>> playlists) {
    if (playlists.hasError && !playlists.hasValue) {
      return SliverToBoxAdapter(
        child: ErrorPanel(error: playlists.error!, onRetry: () => ref.invalidate(playlistsProvider)),
      );
    }
    if (!playlists.hasValue) {
      return const SliverToBoxAdapter(child: SkeletonBox(height: 190, radius: 32));
    }
    final list = playlists.requireValue;
    if (list.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyPanel(
          icon: Icons.queue_music_rounded,
          title: 'No playlists yet',
          message: 'Playlists you make in Navidrome appear here.',
        ),
      );
    }
    return SliverLayoutBuilder(
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
          itemCount: list.length,
          itemBuilder: (context, i) => StaggerIn(
            index: i < 24 ? i : 0,
            child: PlaylistCard(playlist: list[i], large: true),
          ),
        );
      },
    );
  }
}
