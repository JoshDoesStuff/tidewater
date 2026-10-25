import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/destinations.dart';
import '../../app/providers/library_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/motion.dart';
import '../../core/api/library_api.dart';
import '../../core/models/album.dart';
import '../../core/models/track.dart';
import '../widgets/art_tile.dart';
import '../widgets/async_states.dart';
import '../widgets/cover_art.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/ripple.dart';
import '../widgets/effects/stagger_in.dart';
import '../widgets/pressable.dart';
import '../widgets/shapes/morph_path.dart';
import 'page_frame.dart';
import 'widgets/album_card.dart';
import 'widgets/app_header.dart';
import 'widgets/section_header.dart';

/// "Good morning", "Good afternoon", ... from the local hour.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 18) return 'Good afternoon';
  if (h >= 18 && h < 22) return 'Good evening';
  return 'Good night';
}


class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {

  void _showAll(LibraryTab tab, [LibrarySort? sort]) {
    ref.read(libraryTabProvider.notifier).set(tab);
    if (sort != null) ref.read(librarySortProvider.notifier).set(sort);
    context.go(Destination.library.path);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final newest = ref.watch(albumRowProvider(AlbumListType.newest));
    final recent = ref.watch(albumRowProvider(AlbumListType.recent));
    final frequent = ref.watch(albumRowProvider(AlbumListType.frequent));
    // Hearted songs, minus any un-hearted since the list loaded; a row of 20.
    final liked = ref.watch(likedProvider);
    final likedSongs = ref
        .watch(likedSongsProvider)
        .whenData((all) => [for (final t in all) if (liked.contains(t.id)) t].take(20).toList());

    final sections = <Widget>[
      _jumpBackIn(newest, recent),
      SectionHeader(
        title: 'Recently added',
        onAction: () => _showAll(LibraryTab.albums, LibrarySort.recentlyAdded),
      ),
      _CardRow<Album>(
        value: newest,
        onRetry: () => ref.invalidate(albumRowProvider(AlbumListType.newest)),
        emptyTitle: 'No albums yet',
        emptyMessage: 'Add music to your Navidrome library and it will show up here.',
        card: (a) => AlbumCard(album: a, size: 112),
      ),
      if (likedSongs.value?.isNotEmpty ?? false) ...[
        SectionHeader(title: 'Liked songs', onAction: () => context.go(Destination.liked.path)),
        _CardRow<Track>(
          value: likedSongs,
          onRetry: () => ref.invalidate(likedSongsProvider),
          emptyTitle: 'No liked songs yet',
          card: (t) => TrackCard(tracks: likedSongs.requireValue, index: likedSongs.requireValue.indexOf(t), size: 112),
        ),
      ],
      if (frequent.value?.isNotEmpty ?? false) ...[
        const SectionHeader(title: 'Most played', action: null),
        _CardRow<Album>(
          value: frequent,
          onRetry: () => ref.invalidate(albumRowProvider(AlbumListType.frequent)),
          emptyTitle: 'Nothing played yet',
          card: (a) => AlbumCard(album: a, size: 112),
        ),
      ],
    ];

    return PageFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(),
            const SizedBox(height: 22),
            LetterReveal(
              text: greetingFor(DateTime.now()),
              style: text.displaySmall,
              delay: const Duration(milliseconds: 100),
            ),
            ...sections,
          ],
        ),
      ),
    );
  }

  /// Hero cards come from what was played last, topped up with the newest
  /// albums; beside them sits Continue listening whenever a queue exists
  /// (including the one restored from last time).
  Widget _jumpBackIn(AsyncValue<List<Album>> newest, AsyncValue<List<Album>> recent) {
    final Widget body;
    if (newest.hasError && !newest.hasValue) {
      body = ErrorPanel(error: newest.error!, onRetry: () => ref.invalidate(albumRowProvider(AlbumListType.newest)));
    } else if (!newest.hasValue) {
      body = const _CarouselSkeleton();
    } else if (newest.requireValue.isEmpty && (recent.value?.isEmpty ?? true)) {
      body = const EmptyPanel(
        icon: Icons.library_music_rounded,
        title: 'Your library is empty',
        message: 'Add music to your Navidrome server and it will show up here.',
      );
    } else {
      final heroes = _distinct([...?recent.value, ...newest.requireValue]).take(3).toList();
      body = _Carousel(heroes: heroes, resume: ref.watch(currentTrackProvider) != null);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Jump back in', action: null),
        SizedBox(height: newest.hasValue && newest.requireValue.isEmpty ? null : 200, child: body),
      ],
    );
  }

  static List<Album> _distinct(Iterable<Album> albums) {
    final seen = <String>{};
    return [
      for (final a in albums)
        if (seen.add(a.id)) a,
    ];
  }
}

/// Horizontal row of cards with loading, error and empty states.
class _CardRow<T> extends StatelessWidget {
  const _CardRow({
    required this.value,
    required this.onRetry,
    required this.card,
    required this.emptyTitle,
    this.emptyMessage,
  });

  final AsyncValue<List<T>> value;
  final VoidCallback onRetry;
  final Widget Function(T item) card;
  final String emptyTitle;
  final String? emptyMessage;

  static const _rowHeight = 190.0;

  @override
  Widget build(BuildContext context) {
    if (value.hasError && !value.hasValue) {
      return ErrorPanel(error: value.error!, onRetry: onRetry, compact: true);
    }
    if (!value.hasValue) {
      return SizedBox(
        height: _rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          separatorBuilder: (_, _) => const SizedBox(width: 26),
          itemBuilder: (_, _) => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 112, height: 112, radius: 30),
              SizedBox(height: 12),
              SkeletonBox(width: 92, height: 12, radius: 6),
              SizedBox(height: 6),
              SkeletonBox(width: 64, height: 10, radius: 5),
            ],
          ),
        ),
      );
    }
    final items = value.requireValue;
    if (items.isEmpty) return EmptyPanel(icon: Icons.inbox_rounded, title: emptyTitle, message: emptyMessage);
    return SizedBox(
      height: _rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 26),
        itemBuilder: (context, i) => StaggerIn(index: i + 4, child: card(items[i])),
      ),
    );
  }
}

class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final showQuick = box.maxWidth >= 900;
        return Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              const Expanded(child: SkeletonBox(height: 200, radius: 32)),
              if (i < 2 || showQuick) const SizedBox(width: 12),
            ],
            if (showQuick) const SkeletonBox(width: 244, height: 200, radius: 32),
          ],
        );
      },
    );
  }
}

/// Hero cards that spring wider on hover (the rest shrink) plus the Quick
/// picks card. Weights animate on the spring curve.
class _Carousel extends StatefulWidget {
  const _Carousel({required this.heroes, required this.resume});

  final List<Album> heroes;
  final bool resume;

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
        final showQuick = box.maxWidth >= 900 && widget.resume;
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
                          album: widget.heroes[i],
                          hovered: _hover == i,
                          weight: w[i],
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
                    child: SizedBox(width: 244, child: StaggerIn(index: n, child: const _ContinueListening())),
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
    return [for (var i = 0; i < b.length; i++) (i < a.length ? a[i] : b[i]) + (b[i] - (i < a.length ? a[i] : b[i])) * t];
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.album, required this.hovered, required this.weight});

  final Album album;
  final bool hovered;

  /// The card's current (animated) share of the carousel: 1 at rest, 2.2 when
  /// hovered, .55 when another card is.
  final double weight;

  /// Label visibility: fully shown at rest or expanded, gone once the card is
  /// squeezed to its narrowest (the label no longer fits there; the demo just
  /// sliced it off at the card edge).
  double get _labelOpacity => ((weight - .6) / .35).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final d = Motion.of(context, Motion.slow);
    final c = Motion.curve(context, Motion.spring);
    final subtitle = 'Album · ${album.artist}';
    return Pressable(
      onTap: () => ref.read(playbackProvider.notifier).playAlbum(album),
      semanticLabel: '${album.title}, $subtitle',
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
              CoverArt(coverArt: album.coverArt, seedKey: album.id, resolution: 800),
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
                    // Overflowing text fades out softly instead of being sliced.
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: text.titleLarge?.copyWith(color: AppTheme.onArt.withValues(alpha: _labelOpacity)),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: text.bodySmall?.copyWith(
                        fontSize: 13,
                        color: AppTheme.onArt.withValues(alpha: .85 * _labelOpacity),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                // Springy entrance, but a quick exit: when the pointer moves to
                // another card the old button must be gone before the new card
                // has finished expanding.
                child: AnimatedOpacity(
                  opacity: hovered ? 1 : 0,
                  duration: hovered ? d : Motion.of(context, Motion.fast),
                  curve: hovered ? Curves.linear : Motion.standard,
                  child: AnimatedScale(
                    scale: hovered ? 1 : .5,
                    duration: hovered ? d : Motion.of(context, Motion.fast),
                    curve: hovered ? c : Motion.standard,
                    child: AnimatedContainer(
                      duration: hovered ? d : Motion.of(context, Motion.fast),
                      curve: hovered ? c : Motion.standard,
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

/// Picks up the queue (restored from last time or already playing): cover,
/// title, how far along it is, and a button to resume or pause.
class _ContinueListening extends ConsumerWidget {
  const _ContinueListening();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final track = ref.watch(currentTrackProvider);
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    if (track == null) return const SizedBox.shrink();
    final position = ref.watch(positionProvider);
    return Pressable(
      onTap: () => ref.read(playbackProvider.notifier).toggle(),
      semanticLabel: '${playing ? 'Pause' : 'Continue'} ${track.title}, ${track.artist}',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        decoration: BoxDecoration(
          color: s.hovered ? scheme.surfaceContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(s.pressed ? 28 : 32),
        ),
        child: Ripple(
          color: scheme.onSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue listening',
                style: text.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ArtTile(
                    coverArt: track.coverArt,
                    seedKey: track.albumId,
                    resolution: 150,
                    size: 56,
                    params: ShapeKind.cookie.params,
                    morph: 1,
                    spin: playing && !Motion.reduced(context) ? .72 : 0,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: position,
                      builder: (context, p, _) {
                        final total = track.duration.inMilliseconds;
                        final done = total <= 0 ? 0.0 : (p.inMilliseconds / total).clamp(0.0, 1.0);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: done,
                            minHeight: 5,
                            backgroundColor: scheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(scheme.primary),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  AnimatedContainer(
                    duration: Motion.of(context, Motion.medium),
                    curve: Motion.curve(context, Motion.spring),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(playing ? 14 : 22),
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 24,
                      color: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
