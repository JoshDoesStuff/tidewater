import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/motion.dart';
import '../../core/data/fake_library.dart';
import '../widgets/art_tile.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/ripple.dart';
import '../widgets/effects/stagger_in.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import '../widgets/shapes/morph_path.dart';
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
  final bool _reveal = revealOnce('home');

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
            LetterReveal(
              text: 'Good evening',
              style: text.displaySmall,
              delay: const Duration(milliseconds: 150),
              animate: _reveal,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final (i, label) in ['All', 'Albums', 'Artists', 'Playlists'].indexed)
                  StaggerIn(
                    index: i,
                    child: ExpressiveChip(label: label, selected: i == _chip, onTap: () => setState(() => _chip = i)),
                  ),
              ],
            ),
            const SectionHeader(title: 'Jump back in'),
            SizedBox(
              height: 200,
              child: _Carousel(
                heroes: [for (final h in _heroes) (h.index, h.title, h.subtitle)],
                quick: [for (final q in _quickPicks) (q.index, q.title, q.subtitle)],
              ),
            ),
            const SectionHeader(title: 'Recently added'),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: 7,
                separatorBuilder: (_, _) => const SizedBox(width: 26),
                itemBuilder: (context, i) => StaggerIn(
                  index: i + 4,
                  child: AlbumCard(index: 3 + i, size: 112),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Item = (int, String, String);

/// Three hero cards that spring wider on hover (the rest shrink) plus the
/// Quick picks card. Weights animate on the spring curve.
class _Carousel extends StatefulWidget {
  const _Carousel({required this.heroes, required this.quick});

  final List<_Item> heroes;
  final List<_Item> quick;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  /// -1 none, 0..n-1 a hero, n the quick picks card.
  int _hover = -1;

  List<double> get _weights {
    final n = widget.heroes.length;
    if (_hover < 0) return List.filled(n, 1);
    return [for (var i = 0; i < n; i++) i == _hover ? 2.2 : .55];
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.heroes.length;
    return LayoutBuilder(
      builder: (context, box) {
        final showQuick = box.maxWidth >= 900;
        final gaps = 12.0 * (n - 1) + (showQuick ? 12 : 0);
        final total = box.maxWidth - gaps - (showQuick ? 244 : 0);
        return TweenAnimationBuilder<List<double>>(
          tween: _WeightsTween(end: _weights),
          duration: Motion.of(context, Motion.slow),
          curve: Motion.curve(context, Motion.spring),
          builder: (context, w, _) {
            final sum = w.fold<double>(0, (a, b) => a + b);
            return Row(
              children: [
                for (var i = 0; i < n; i++) ...[
                  MouseRegion(
                    onEnter: (_) => setState(() => _hover = i),
                    onExit: (_) => setState(() => _hover = -1),
                    child: SizedBox(
                      width: (total * w[i] / sum).clamp(0.0, double.infinity),
                      child: StaggerIn(
                        index: i,
                        child: _HeroCard(
                          index: widget.heroes[i].$1,
                          title: widget.heroes[i].$2,
                          subtitle: widget.heroes[i].$3,
                          hovered: _hover == i,
                        ),
                      ),
                    ),
                  ),
                  if (i < n - 1 || showQuick) const SizedBox(width: 12),
                ],
                if (showQuick)
                  MouseRegion(
                    onEnter: (_) => setState(() => _hover = n),
                    onExit: (_) => setState(() => _hover = -1),
                    child: SizedBox(width: 244, child: StaggerIn(index: n, child: _QuickPicks(picks: widget.quick))),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WeightsTween extends Tween<List<double>> {
  _WeightsTween({super.end});

  @override
  List<double> lerp(double t) {
    final a = begin ?? end!;
    final b = end!;
    return [for (var i = 0; i < b.length; i++) a[i] + (b[i] - a[i]) * t];
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.index, required this.title, required this.subtitle, required this.hovered});

  final int index;
  final String title;
  final String subtitle;
  final bool hovered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final d = Motion.of(context, Motion.slow);
    final c = Motion.curve(context, Motion.spring);
    return Pressable(
      onTap: () => ref.read(playbackProvider.notifier).playIndex(index),
      semanticLabel: '$title, $subtitle',
      builder: (context, s) => AnimatedContainer(
        duration: d,
        curve: c,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(hovered ? 40 : 32)),
        child: Ripple(
          color: AppTheme.onArt,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ArtFill(album: fakeAlbums[index]),
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
                right: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: text.titleLarge?.copyWith(color: AppTheme.onArt),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: text.bodySmall?.copyWith(fontSize: 13, color: AppTheme.onArt.withValues(alpha: .85)),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: AnimatedOpacity(
                  opacity: hovered ? 1 : 0,
                  duration: d,
                  child: AnimatedScale(
                    scale: hovered ? 1 : .5,
                    duration: d,
                    curve: c,
                    child: AnimatedContainer(
                      duration: d,
                      curve: c,
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(hovered ? 18 : 26),
                      ),
                      child: Icon(Icons.play_arrow_rounded, size: 26, color: scheme.onPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.picks});

  final List<_Item> picks;

  static const _kinds = [ShapeKind.cookie, ShapeKind.sunny, ShapeKind.clover];

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
            for (final (i, (index, title, subtitle)) in picks.indexed)
              _QuickPick(index: index, title: title, subtitle: subtitle, kind: _kinds[i % 3], reverse: i.isOdd),
          ],
        ),
      ),
    );
  }
}

class _QuickPick extends ConsumerWidget {
  const _QuickPick({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.reverse,
  });

  final int index;
  final String title;
  final String subtitle;
  final ShapeKind kind;
  final bool reverse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => ref.read(playbackProvider.notifier).playIndex(index),
      semanticLabel: '$title, $subtitle',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: s.hovered ? scheme.surfaceContainerHigh : scheme.surfaceContainerHigh.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Ripple(
          color: scheme.onSurface,
          child: Row(
            children: [
              ArtTile(
                album: fakeAlbums[index],
                size: 36,
                params: kind.params,
                morph: 1,
                spin: Motion.reduced(context) ? 0 : (reverse ? -.72 : .72),
              ),
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
    );
  }
}
