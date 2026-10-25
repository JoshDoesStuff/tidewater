import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/stagger_in.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import 'page_frame.dart';
import 'widgets/album_card.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  static const _gap = 26.0;
  static const _cardWidth = 156.0;

  final _scroll = ScrollController();
  final _headerKey = GlobalKey();

  /// Grid geometry from the last layout, for the A–Z jump.
  int _columns = 1;
  double _rowExtent = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls so the row holding item [index] is at the top of the grid.
  void _jumpToIndex(int index) {
    if (!_scroll.hasClients || _columns < 1) return;
    final header = (_headerKey.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0;
    final target = header + (index ~/ _columns) * (_rowExtent + _gap);
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.curve(context, Motion.emphasized),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(libraryTabProvider);
    final sort = ref.watch(librarySortProvider);
    final genre = ref.watch(libraryGenreProvider);
    final albums = ref.watch(libraryAlbumsProvider(sort));
    final artists = ref.watch(artistsProvider);
    final playlists = ref.watch(playlistsProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // What the grid shows for the current tab.
    final List<Album> shownAlbums = [
      for (final a in albums.value?.albums ?? const <Album>[])
        if (genre == null || a.genre == genre) a,
    ];
    final String subtitle;
    switch (tab) {
      case LibraryTab.albums:
        final loaded = albums.value;
        if (loaded == null) {
          subtitle = albums.hasError ? 'Couldn\'t load albums' : 'Loading…';
        } else {
          final n = shownAlbums.length;
          final label = genre != null ? '$n ${genre.toLowerCase()} album${n == 1 ? '' : 's'}' : '$n album${n == 1 ? '' : 's'}';
          subtitle = loaded.complete ? label : '$label so far…';
        }
      case LibraryTab.artists:
        final n = artists.value?.length;
        subtitle = n == null ? (artists.hasError ? 'Couldn\'t load artists' : 'Loading…') : '$n artist${n == 1 ? '' : 's'}';
      case LibraryTab.playlists:
        final n = playlists.value?.length;
        subtitle = n == null ? (playlists.hasError ? 'Couldn\'t load playlists' : 'Loading…') : '$n playlist${n == 1 ? '' : 's'}';
    }

    final genres = {
      for (final a in albums.value?.albums ?? const <Album>[])
        if (a.genre != null) a.genre!,
    }.toList()
      ..sort();

    // A–Z jump only makes sense when the list is alphabetical.
    final alphabetical = (tab == LibraryTab.albums && (sort == LibrarySort.name || sort == LibrarySort.artist)) ||
        tab == LibraryTab.artists;
    List<String> titlesForRail() => switch (tab) {
          LibraryTab.albums => [for (final a in shownAlbums) sort == LibrarySort.artist ? a.artist : a.title],
          LibraryTab.artists => [for (final a in artists.value ?? const <Artist>[]) a.name],
          LibraryTab.playlists => const [],
        };

    return PageFrame(
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            // Build about two rows ahead, so covers are decoded before they scroll in.
            scrollCacheExtent: const ScrollCacheExtent.pixels(700),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 36, 40, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    key: _headerKey,
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
                          if (tab == LibraryTab.albums) ...[
                            _MenuPill<LibrarySort>(
                              icon: Icons.sort_rounded,
                              label: sort.label,
                              semanticLabel: 'Sort: ${sort.label}',
                              value: sort,
                              entries: [for (final s in LibrarySort.values) (s, s.label)],
                              onSelected: ref.read(librarySortProvider.notifier).set,
                            ),
                            const SizedBox(width: 6),
                            _MenuPill<String>(
                              icon: Icons.filter_list_rounded,
                              label: genre ?? 'Genre',
                              semanticLabel: genre == null ? 'Filter by genre' : 'Genre: $genre',
                              value: genre ?? '',
                              highlighted: genre != null,
                              entries: [('', 'All genres'), for (final g in genres) (g, g)],
                              onSelected: (g) => ref.read(libraryGenreProvider.notifier).set(g.isEmpty ? null : g),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final (i, t) in LibraryTab.values.indexed)
                            StaggerIn(
                              index: i,
                              child: ExpressiveChip(
                                label: t.label,
                                selected: t == tab,
                                onTap: () => ref.read(libraryTabProvider.notifier).set(t),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
              ..._body(tab, sort, albums, shownAlbums, artists, playlists),
            ],
          ),
          if (alphabetical)
            Positioned(
              right: 6,
              top: 168,
              bottom: PageFrame.bottomClearance,
              child: _AlphaRail(titles: titlesForRail(), onJump: _jumpToIndex),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(
    LibraryTab tab,
    LibrarySort sort,
    AsyncValue<LibraryAlbums> albums,
    List<Album> shownAlbums,
    AsyncValue<List<Artist>> artists,
    AsyncValue<List<Playlist>> playlists,
  ) {
    switch (tab) {
      case LibraryTab.albums:
        if (albums.hasError && !albums.hasValue) {
          return [_message(ErrorPanel(error: albums.error!, onRetry: () => ref.invalidate(libraryAlbumsProvider(sort))))];
        }
        if (!albums.hasValue) return [_skeletonGrid(round: false)];
        if (shownAlbums.isEmpty && albums.requireValue.complete) {
          return [
            _message(EmptyPanel(
              icon: Icons.album_rounded,
              title: ref.read(libraryGenreProvider) == null ? 'No albums yet' : 'No albums in this genre',
              message: ref.read(libraryGenreProvider) == null ? 'Add music to your Navidrome library and it will show up here.' : null,
            )),
          ];
        }
        return [
          _grid(shownAlbums.length, (i) => AlbumCard(album: shownAlbums[i], large: true)),
          if (albums.hasError)
            _message(
              ErrorPanel(error: albums.error!, compact: true, onRetry: () => ref.invalidate(libraryAlbumsProvider(sort))),
              bottom: true,
            ),
        ];
      case LibraryTab.artists:
        if (artists.hasError && !artists.hasValue) {
          return [_message(ErrorPanel(error: artists.error!, onRetry: () => ref.invalidate(artistsProvider)))];
        }
        if (!artists.hasValue) return [_skeletonGrid(round: true)];
        final list = artists.requireValue;
        if (list.isEmpty) return [_message(const EmptyPanel(icon: Icons.person_rounded, title: 'No artists yet'))];
        return [_grid(list.length, (i) => ArtistCard(artist: list[i], large: true))];
      case LibraryTab.playlists:
        if (playlists.hasError && !playlists.hasValue) {
          return [_message(ErrorPanel(error: playlists.error!, onRetry: () => ref.invalidate(playlistsProvider)))];
        }
        if (!playlists.hasValue) return [_skeletonGrid(round: false)];
        final list = playlists.requireValue;
        if (list.isEmpty) {
          return [
            _message(const EmptyPanel(
              icon: Icons.queue_music_rounded,
              title: 'No playlists yet',
              message: 'Playlists you make in Navidrome appear here.',
            )),
          ];
        }
        return [_grid(list.length, (i) => PlaylistCard(playlist: list[i], large: true))];
    }
  }

  Widget _message(Widget child, {bool bottom = false}) => SliverPadding(
        padding: EdgeInsets.fromLTRB(24, bottom ? 20 : 0, 40, PageFrame.bottomClearance),
        sliver: SliverToBoxAdapter(child: child),
      );

  SliverPadding _grid(int count, Widget Function(int index) card) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 40, PageFrame.bottomClearance),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final (columns, tile) = _geometry(constraints.crossAxisExtent);
          // Cover + gap + title + subtitle.
          final extent = tile + 14 + 40;
          _columns = columns;
          _rowExtent = extent;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
              mainAxisExtent: extent,
            ),
            itemCount: count,
            itemBuilder: (context, i) => StaggerIn(index: i < 24 ? i : 0, child: card(i)),
          );
        },
      ),
    );
  }

  (int, double) _geometry(double available) {
    final columns = ((available + _gap) / (_cardWidth + _gap)).floor().clamp(2, 12);
    return (columns, (available - (columns - 1) * _gap) / columns);
  }

  Widget _skeletonGrid({required bool round}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 40, PageFrame.bottomClearance),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final (columns, tile) = _geometry(constraints.crossAxisExtent);
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
                SkeletonBox(width: tile, height: tile, radius: tile * .26, circle: round),
                const SizedBox(height: 14),
                const SkeletonBox(width: 110, height: 12, radius: 6),
                const SizedBox(height: 6),
                const SkeletonBox(width: 72, height: 10, radius: 5),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Pill that opens a menu of choices (sort order, genre).
class _MenuPill<T> extends StatefulWidget {
  const _MenuPill({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.entries,
    required this.onSelected,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final T value;
  final List<(T, String)> entries;
  final ValueChanged<T> onSelected;

  /// Drawn like a selected button (a filter is active).
  final bool highlighted;

  @override
  State<_MenuPill<T>> createState() => _MenuPillState<T>();
}

class _MenuPillState<T> extends State<_MenuPill<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.highlighted
        ? scheme.secondaryContainer
        : (_hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh);
    final fg = widget.highlighted ? scheme.onSecondaryContainer : scheme.onSurface;
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: ExcludeSemantics(
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: PopupMenuButton<T>(
            tooltip: '',
            initialValue: widget.value,
            offset: const Offset(0, 54),
            color: scheme.surfaceContainerHigh,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onSelected: widget.onSelected,
            itemBuilder: (context) => [
              for (final (value, label) in widget.entries)
                PopupMenuItem<T>(
                  value: value,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: value == widget.value ? FontWeight.w700 : FontWeight.w500,
                      color: value == widget.value ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
            ],
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              height: 48,
              padding: const EdgeInsets.only(left: 18, right: 20),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: fg),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.expand_more_rounded, size: 16, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Words the server ignores when alphabetizing ("The Beatles" lives under B).
const _ignoredArticles = ['the ', 'an ', 'a ', 'el ', 'la ', 'los ', 'las ', 'le ', 'les ', 'os ', 'as ', 'o '];

String _initial(String title, {required bool skipArticles}) {
  var t = title.trim().toLowerCase();
  if (skipArticles) {
    for (final a in _ignoredArticles) {
      if (t.startsWith(a) && t.length > a.length) {
        t = t.substring(a.length);
        break;
      }
    }
  }
  if (t.isEmpty) return '#';
  final c = t[0].toUpperCase();
  return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
}

/// Index of the first title that starts with [letter], preferring the
/// server's article-skipping order; -1 when none does.
int firstIndexForLetter(List<String> titles, String letter) {
  for (final skip in const [true, false]) {
    final i = titles.indexWhere((t) => _initial(t, skipArticles: skip) == letter);
    if (i >= 0) return i;
  }
  return -1;
}

/// A–Z jump rail along the right edge. Letters with nothing in the list (so
/// far) are dimmed and do nothing.
class _AlphaRail extends StatelessWidget {
  const _AlphaRail({required this.titles, required this.onJump});

  final List<String> titles;
  final ValueChanged<int> onJump;

  static final _letters = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = [for (var i = 0; i < _letters.length; i += 2) _letters[i]];
    final present = <String>{for (final l in _letters) if (firstIndexForLetter(titles, l) >= 0) l};
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
                onTap: () {
                  // The rail shows every other letter; jump to this letter, or
                  // to the next one that exists.
                  final from = _letters.indexOf(l);
                  for (var i = from; i < _letters.length; i++) {
                    final at = firstIndexForLetter(titles, _letters[i]);
                    if (at >= 0) {
                      onJump(at);
                      return;
                    }
                  }
                  if (titles.isNotEmpty) onJump(titles.length - 1);
                },
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
                          color: s.hovered
                              ? scheme.onPrimary
                              : (present.contains(l) ? scheme.onSurfaceVariant : scheme.onSurfaceVariant.withValues(alpha: .4)),
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
