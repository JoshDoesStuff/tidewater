import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/fake_library.dart';
import '../../core/models/album.dart';
import '../widgets/art_tile.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import 'page_frame.dart';
import 'widgets/album_card.dart';
import 'widgets/app_header.dart';
import 'widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _chip = 0;

  static const _heroes = [
    (index: 0, title: 'Glass Orchard', subtitle: 'Album · Mira Vale'),
    (index: 7, title: 'Daily Mix 1', subtitle: 'Playlist'),
    (index: 2, title: 'Low Tide Letters', subtitle: 'Album · Ana Soleil'),
  ];

  static const _quickPicks = [
    (index: 6, title: 'Late Night Drive', subtitle: '64 songs'),
    (index: 8, title: 'Focus', subtitle: 'Playlist'),
    (index: 10, title: 'Liked Songs', subtitle: '842 songs'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PageFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(),
            const SizedBox(height: 22),
            Text('Good evening', style: text.displaySmall),
            const SizedBox(height: 14),
            ExpressiveChipGroup(
              labels: const ['All', 'Albums', 'Artists', 'Playlists'],
              selectedIndex: _chip,
              onSelected: (i) => setState(() => _chip = i),
            ),
            const SectionHeader(title: 'Jump back in'),
            SizedBox(
              height: 200,
              child: LayoutBuilder(
                builder: (context, box) {
                  final showQuick = box.maxWidth >= 900;
                  return Row(
                    children: [
                      for (final h in _heroes) ...[
                        Expanded(child: _HeroCard(album: fakeAlbums[h.index], title: h.title, subtitle: h.subtitle)),
                        const SizedBox(width: 12),
                      ],
                      if (showQuick)
                        SizedBox(
                          width: 244,
                          child: _QuickPicks(
                            picks: [for (final q in _quickPicks) (fakeAlbums[q.index], q.title, q.subtitle)],
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  );
                },
              ),
            ),
            const SectionHeader(title: 'Recently added'),
            SizedBox(
              height: 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, _) => const SizedBox(width: 26),
                itemBuilder: (context, i) => AlbumCard(album: fakeAlbums[3 + i], size: 112),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.album, required this.title, required this.subtitle});

  final Album album;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () {},
      semanticLabel: '$title, $subtitle',
      builder: (context, s) => ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArtTile(album: album, squircle: false),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(0, -.3),
                  end: Alignment.bottomCenter,
                  colors: [scheme.scrim.withValues(alpha: 0), scheme.scrim.withValues(alpha: .62)],
                ),
              ),
            ),
            Positioned(
              left: 26,
              bottom: 22,
              right: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge?.copyWith(color: AppTheme.onArt),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(fontSize: 13, color: AppTheme.onArt.withValues(alpha: .85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.picks});

  final List<(Album, String, String)> picks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick picks', style: text.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 8),
            for (final (album, title, subtitle) in picks)
              Pressable(
                onTap: () {},
                semanticLabel: '$title, $subtitle',
                builder: (context, s) => Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: s.hovered ? scheme.surfaceContainerHigh : scheme.surfaceContainerHigh.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      ArtTile(album: album, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(fontSize: 11.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
