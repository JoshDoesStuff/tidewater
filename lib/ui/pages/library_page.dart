import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';
import '../../core/data/fake_library.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/ripple.dart';
import '../widgets/effects/stagger_in.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import 'page_frame.dart';
import 'widgets/album_card.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const _gap = 26.0;
  static const _cardWidth = 156.0;

  int _chip = 0;
  final bool _reveal = revealOnce('library');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PageFrame(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 36, 40, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LetterReveal(
                                  text: 'Library',
                                  style: text.displaySmall,
                                  delay: const Duration(milliseconds: 100),
                                  animate: _reveal,
                                ),
                                Text(
                                  '1,284 albums · 96 GB',
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const _SortButton(label: 'Recently added'),
                          const SizedBox(width: 6),
                          const ExpressiveIconButton(icon: Icons.grid_view_rounded, selected: true, tooltip: 'Grid'),
                          const SizedBox(width: 6),
                          const ExpressiveIconButton(icon: Icons.filter_list_rounded, tooltip: 'Filter'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final (i, label) in ['Albums', 'Artists', 'Songs', 'Playlists', 'Genres'].indexed)
                            StaggerIn(
                              index: i,
                              child: ExpressiveChip(
                                label: label,
                                selected: i == _chip,
                                onTap: () => setState(() => _chip = i),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 40, PageFrame.bottomClearance),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final available = constraints.crossAxisExtent;
                    final count = ((available + _gap) / (_cardWidth + _gap)).floor().clamp(2, 12);
                    final tile = (available - (count - 1) * _gap) / count;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        mainAxisSpacing: _gap,
                        crossAxisSpacing: _gap,
                        // Cover + gap + title + artist.
                        mainAxisExtent: tile + 14 + 40,
                      ),
                      itemCount: fakeAlbums.length,
                      itemBuilder: (context, i) => StaggerIn(index: i, child: AlbumCard(index: i, large: true)),
                    );
                  },
                ),
              ),
            ],
          ),
          const Positioned(right: 6, top: 168, bottom: PageFrame.bottomClearance, child: _AlphaRail()),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () {},
      semanticLabel: 'Sort: $label',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: s.hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Ripple(
          color: scheme.onSurface,
          child: Padding(
            padding: const EdgeInsets.only(left: 18, right: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort_rounded, size: 20, color: scheme.onSurface),
                const SizedBox(width: 10),
                Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                Icon(Icons.expand_more_rounded, size: 16, color: scheme.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A–Z jump rail along the right edge.
class _AlphaRail extends StatelessWidget {
  const _AlphaRail();

  static final _letters = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = [for (var i = 0; i < _letters.length; i += 2) _letters[i]];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 520),
      child: Container(
        width: 22,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(11)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final l in shown)
              Pressable(
                onTap: () {},
                semanticLabel: 'Jump to $l',
                builder: (context, s) => AnimatedContainer(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.curve(context, Motion.spring),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(s.hovered ? 1.35 : 1, s.hovered ? 1.35 : 1, 1),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.hovered ? scheme.primary : scheme.primary.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    l,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: s.hovered ? scheme.onPrimary : scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
