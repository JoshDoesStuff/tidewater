import 'dart:math' as math;
import 'dart:ui' as ui;

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
import '../widgets/animated_glyphs.dart';
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
  static const _cardSize = 112.0;
  static const _cardGap = 26.0;
  static const _pagePad = 24.0 + 32.0;

  final _random = math.Random();

  /// The three hero picks, kept until their lists change so the carousel
  /// doesn't reshuffle on every rebuild.
  String? _randomId, _recentId, _newId;

  void _showAll(LibraryTab tab, [LibrarySort? sort]) {
    ref.read(libraryTabProvider.notifier).set(tab);
    if (sort != null) ref.read(librarySortProvider.notifier).set(sort);
    context.go(Destination.library.path);
  }

  /// How many cards fit in one row at this window width.
  static int _fit(double width) =>
      (((width - _pagePad + _cardGap) / (_cardSize + _cardGap)).floor()).clamp(1, 20);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final newest = ref.watch(albumRowProvider(AlbumListType.newest));
    final recent = ref.watch(albumRowProvider(AlbumListType.recent));
    final frequent = ref.watch(albumRowProvider(AlbumListType.frequent));
    final random = ref.watch(albumRowProvider(AlbumListType.random));

    return PageFrame(
      child: LayoutBuilder(
        builder: (context, box) {
          final fit = _fit(box.maxWidth);
          final shown = newest.whenData((l) => l.take(fit).toList());
          final heroes = _heroes(shown, recent, random);
          final picked = {for (final h in heroes.albums) h.id};
          final sections = <Widget>[
            _jumpBackIn(newest, recent, heroes),
            SectionHeader(
              title: 'Recently added',
              onAction: () => _showAll(LibraryTab.albums, LibrarySort.recentlyAdded),
            ),
            _CardRow<Album>(
              value: shown,
              onRetry: () => ref.invalidate(albumRowProvider(AlbumListType.newest)),
              emptyTitle: 'No albums yet',
              emptyMessage: 'Add music to your Navidrome library and it will show up here.',
              card: (a) => AlbumCard(album: a, size: _cardSize),
            ),
            if (random.value?.isNotEmpty ?? false) ...[
              SectionHeader(
                title: 'Random albums',
                trailing: _ShufflePicksButton(
                  onPressed: () {
                    _randomId = null;
                    ref.invalidate(albumRowProvider(AlbumListType.random));
                  },
                ),
              ),
              // A new set of picks swaps in with a fade and rise, and its cards
              // cascade in one after another.
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.slow),
                switchInCurve: Motion.curve(context, Motion.emphasized),
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, ?current],
                ),
                child: _CardRow<Album>(
                  key: ValueKey(random.value?.map((a) => a.id).join(',')),
                  value: random.whenData(
                    (l) => [for (final a in l) if (!picked.contains(a.id)) a].take(fit).toList(),
                  ),
                  onRetry: () => ref.invalidate(albumRowProvider(AlbumListType.random)),
                  emptyTitle: 'Nothing to suggest',
                  card: (a) => AlbumCard(album: a, size: _cardSize),
                ),
              ),
            ],
            if (frequent.value?.isNotEmpty ?? false) ...[
              const SectionHeader(title: 'Most played', action: null),
              _CardRow<Album>(
                value: frequent.whenData((l) => l.take(fit).toList()),
                onRetry: () => ref.invalidate(albumRowProvider(AlbumListType.frequent)),
                emptyTitle: 'Nothing played yet',
                card: (a) => AlbumCard(album: a, size: _cardSize),
              ),
            ],
          ];
          return SingleChildScrollView(
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
          );
        },
      ),
    );
  }

  /// One album from all albums (random), one from recently played, one from
  /// the Recently added row as shown. Kept stable until a list changes.
  ({List<Album> albums, List<String> tags}) _heroes(
    AsyncValue<List<Album>> shown,
    AsyncValue<List<Album>> recent,
    AsyncValue<List<Album>> random,
  ) {
    final taken = <String>{};
    Album? choose(List<Album>? from, String? current, void Function(String?) set) {
      final pool = [for (final a in from ?? const <Album>[]) if (!taken.contains(a.id)) a];
      if (pool.isEmpty) return null;
      final keep = pool.where((a) => a.id == current);
      final a = keep.isNotEmpty ? keep.first : pool[_random.nextInt(pool.length)];
      set(a.id);
      taken.add(a.id);
      return a;
    }

    final fromRecent = choose(recent.value, _recentId, (id) => _recentId = id);
    final fromNew = choose(shown.value, _newId, (id) => _newId = id);
    final fromAll = choose(random.value, _randomId, (id) => _randomId = id);
    return (
      albums: [?fromAll, ?fromRecent, ?fromNew],
      tags: [if (fromAll != null) 'Random', if (fromRecent != null) 'Recently played', if (fromNew != null) 'New'],
    );
  }

  /// Hero cards come from [heroes]; beside them sits Continue listening
  /// whenever a queue exists (including the one restored from last time).
  Widget _jumpBackIn(
    AsyncValue<List<Album>> newest,
    AsyncValue<List<Album>> recent,
    ({List<Album> albums, List<String> tags}) picks,
  ) {
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
      body = _Carousel(
        heroes: picks.albums,
        tags: picks.tags,
        resume: ref.watch(currentTrackProvider) != null,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Jump back in', action: null),
        SizedBox(height: newest.hasValue && newest.requireValue.isEmpty ? null : 200, child: body),
      ],
    );
  }

}

/// Horizontal row of cards with loading, error and empty states.
class _CardRow<T> extends StatelessWidget {
  const _CardRow({
    super.key,
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
    // Callers trim the list to what fits, so the row never scrolls.
    return SizedBox(
      height: _rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 26),
            StaggerIn(index: i + 4, child: card(items[i])),
          ],
        ],
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
            if (showQuick) const SkeletonBox(width: 300, height: 200, radius: 32),
          ],
        );
      },
    );
  }
}

/// Hero cards that spring wider on hover (the rest shrink) plus the Quick
/// picks card. Weights animate on the spring curve.
class _Carousel extends StatefulWidget {
  const _Carousel({required this.heroes, required this.tags, required this.resume});

  final List<Album> heroes;
  final List<String> tags;
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
        final total = box.maxWidth - gaps - (showQuick ? _ContinueListening.width : 0);
        return TweenAnimationBuilder<List<double>>(
          tween: _WeightsTween(end: _weights),
          duration: Motion.of(context, Motion.slow),
          curve: Motion.curve(context, Motion.spring),
          builder: (context, w, _) {
            final sum = w.fold<double>(0, (a, b) => a + b);
            return Row(
              children: [
                if (showQuick) ...[
                  SizedBox(width: _ContinueListening.width, child: StaggerIn(index: 0, child: const _ContinueListening())),
                  const SizedBox(width: 12),
                ],
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
                          tag: widget.tags[i],
                          hovered: _hover == i,
                          weight: w[i],
                        ),
                      ),
                    ),
                  ),
                  if (i < n - 1) const SizedBox(width: 12),
                ],
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
  const _HeroCard({required this.album, required this.tag, required this.hovered, required this.weight});

  final Album album;

  /// Why it is here: "Recently played" or "New".
  final String tag;
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
              // A wash of the accent from the bottom corner ties the card to the theme.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomLeft,
                    radius: 1.1,
                    colors: [scheme.primary.withValues(alpha: .28), scheme.primary.withValues(alpha: 0)],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                  opacity: _labelOpacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.scrim.withValues(alpha: .38),
                      borderRadius: BorderRadius.circular(hovered ? 10 : 14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            switch (tag) {
                              'New' => Icons.auto_awesome_rounded,
                              'Random' => Icons.casino_rounded,
                              _ => Icons.history_rounded,
                            },
                            size: 14,
                            color: AppTheme.onArt,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tag.toUpperCase(),
                            maxLines: 1,
                            softWrap: false,
                            style: text.labelSmall?.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppTheme.onArt,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
/// title, how far along it is, and a button to resume or pause. Hovering
/// lifts the card, tints it with the accent and springs the button bigger.
class _ContinueListening extends ConsumerWidget {
  const _ContinueListening();

  static const width = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final track = ref.watch(currentTrackProvider);
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    if (track == null) return const SizedBox.shrink();
    final position = ref.watch(positionProvider);
    final d = Motion.of(context, Motion.medium);
    final spring = Motion.curve(context, Motion.spring);
    return Pressable(
      onTap: () => ref.read(playbackProvider.notifier).toggle(),
      semanticLabel: '${playing ? 'Pause' : 'Continue'} ${track.title}, ${track.artist}',
      builder: (context, s) => AnimatedScale(
        scale: s.pressed ? .97 : (s.hovered ? 1.03 : 1),
        duration: d,
        curve: spring,
        child: AnimatedContainer(
          duration: d,
          curve: Motion.standard,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Color.lerp(scheme.surfaceContainerLow, scheme.primaryContainer, s.hovered ? .45 : 0),
            borderRadius: BorderRadius.circular(s.hovered ? 40 : 32),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The cover, blurred and faded, as a backdrop; a scrim from the
              // left keeps the text readable.
              RepaintBoundary(
                child: Opacity(
                  opacity: s.hovered ? .5 : .34,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.clamp),
                    child: CoverArt(coverArt: track.coverArt, seedKey: track.albumId, resolution: 150),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.surfaceContainerLow.withValues(alpha: .9), scheme.surfaceContainerLow.withValues(alpha: .2)],
                  ),
                ),
              ),
          Ripple(
            color: scheme.onSurface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continue listening',
                  style: text.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ArtTile(
                      coverArt: track.coverArt,
                      seedKey: track.albumId,
                      resolution: 300,
                      size: 64,
                      params: ShapeKind.cookie.params,
                      morph: 1,
                      spin: (playing || s.hovered) && !Motion.reduced(context) ? .72 : 0,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.25),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(fontSize: 12.5, color: scheme.onSurfaceVariant),
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
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(scheme.primary),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    AnimatedContainer(
                      duration: d,
                      curve: spring,
                      width: s.hovered ? 56 : 48,
                      height: s.hovered ? 56 : 48,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(playing ? 16 : (s.hovered ? 28 : 24)),
                      ),
                      child: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: s.hovered ? 28 : 25,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
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

/// "Shuffle picks": a tonal pill whose shuffle icon plays on each press and
/// whose arrows keep turning for a moment, so a reroll feels like something
/// happened even before the new albums arrive.
class _ShufflePicksButton extends StatelessWidget {
  const _ShufflePicksButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onPressed,
      semanticLabel: 'Shuffle picks',
      builder: (context, s) => AnimatedScale(
        scale: s.pressed ? .94 : 1,
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curve(context, Motion.spring),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.curve(context, Motion.spring),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: s.hovered ? Color.lerp(scheme.secondaryContainer, scheme.onSecondaryContainer, .08) : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(s.pressed ? 12 : 20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedGlyph(kind: GlyphKind.shuffle, size: 20, color: scheme.onSecondaryContainer, active: s.pressed),
              const SizedBox(width: 8),
              Text(
                'Shuffle picks',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
