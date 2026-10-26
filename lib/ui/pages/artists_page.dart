import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/artist.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/stagger_in.dart';
import 'library_page.dart' show AlphaRail;
import 'page_frame.dart';
import 'widgets/album_card.dart';

/// Every artist as a grid of round cards with an A–Z jump rail.
class ArtistsPage extends ConsumerStatefulWidget {
  const ArtistsPage({super.key});

  @override
  ConsumerState<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends ConsumerState<ArtistsPage> {
  static const _gap = 26.0;
  static const _cardWidth = 156.0;
  static const _headerHeight = 36.0 + 80.0 + 22.0;

  final _scroll = ScrollController();
  int _columns = 1;
  double _rowExtent = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  (int, double) _geometry(double available) {
    final columns = ((available + _gap) / (_cardWidth + _gap)).floor().clamp(2, 12);
    return (columns, (available - (columns - 1) * _gap) / columns);
  }

  void _jumpToIndex(int index) {
    if (!_scroll.hasClients || _columns < 1) return;
    final target = _headerHeight + (index ~/ _columns) * (_rowExtent + _gap);
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.curve(context, Motion.emphasized),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artists = ref.watch(artistsProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final n = artists.value?.length;
    final subtitle = n == null
        ? (artists.hasError ? 'Couldn\'t load artists' : 'Loading…')
        : '$n artist${n == 1 ? '' : 's'}';

    return PageFrame(
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            scrollCacheExtent: const ScrollCacheExtent.pixels(700),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 36, 40, 22),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LetterReveal(
                          text: 'Artists',
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
              ),
              ..._body(artists),
            ],
          ),
          if (artists.hasValue)
            Positioned(
              right: 6,
              top: 168,
              bottom: PageFrame.bottomClearance,
              child: AlphaRail(
                titles: [for (final a in artists.requireValue) a.name],
                onJump: _jumpToIndex,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(AsyncValue<List<Artist>> artists) {
    const pad = EdgeInsets.fromLTRB(24, 0, 40, PageFrame.bottomClearance);
    if (artists.hasError && !artists.hasValue) {
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(
            child: ErrorPanel(
              error: artists.error!,
              onRetry: () => ref.invalidate(artistsProvider),
            ),
          ),
        ),
      ];
    }
    if (!artists.hasValue) {
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverLayoutBuilder(
            builder: (context, c) {
              final (columns, tile) = _geometry(c.crossAxisExtent);
              return SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: _gap,
                  crossAxisSpacing: _gap,
                  mainAxisExtent: tile + 14 + 40,
                ),
                itemCount: columns * 3,
                itemBuilder: (context, i) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: tile, height: tile, radius: tile * .26, circle: true),
                    const SizedBox(height: 14),
                    const SkeletonBox(width: 110, height: 12, radius: 6),
                    const SizedBox(height: 6),
                    const SkeletonBox(width: 72, height: 10, radius: 5),
                  ],
                ),
              );
            },
          ),
        ),
      ];
    }
    final list = ref.read(artistsProvider).requireValue;
    if (list.isEmpty) {
      return [
        SliverPadding(
          padding: pad,
          sliver: const SliverToBoxAdapter(
            child: EmptyPanel(icon: Icons.person_rounded, title: 'No artists yet'),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: pad,
        sliver: SliverLayoutBuilder(
          builder: (context, c) {
            final (columns, tile) = _geometry(c.crossAxisExtent);
            _columns = columns;
            _rowExtent = tile + 14 + 40;
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: _gap,
                crossAxisSpacing: _gap,
                mainAxisExtent: _rowExtent,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) => StaggerIn(
                index: i < columns * 8 ? i ~/ columns + i % columns : 0,
                child: ArtistCard(artist: list[i], large: true),
              ),
            );
          },
        ),
      ),
    ];
  }
}
