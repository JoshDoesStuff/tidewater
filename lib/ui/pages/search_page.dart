import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/list_cache_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/providers/search_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/search_results.dart';
import '../../core/search/library_index.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/stagger_in.dart';
import '../widgets/pressable.dart';
import '../widgets/squiggle_loader.dart';
import 'album_page.dart' show goBack;
import 'page_frame.dart';
import 'widgets/album_card.dart';
import 'widgets/app_header.dart';
import 'widgets/section_header.dart';
import 'widgets/song_row.dart';

/// One line of the autosuggest list: a recent search or a match from the
/// library index.
class _Pick {
  const _Pick.recent(this.text) : suggestion = null;
  _Pick.match(Suggestion s) : text = s.title, suggestion = s;

  final String text;
  final Suggestion? suggestion;

  bool get isRecent => suggestion == null;
}

/// Search the library: artists, albums and songs for what is typed, or the
/// recent searches while nothing is. While typing, a list of suggestions from
/// the whole library (instant, from a local index) drops down under the field.
/// Keyboard first: `Ctrl+K` or `/` opens it with the field focused, the arrow
/// keys move through the suggestions, `Enter` searches (or takes the highlighted
/// suggestion), `Esc` closes the list, then clears the field, then leaves.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _gap = 26.0;

  late final TextEditingController _controller = TextEditingController(text: ref.read(searchQueryProvider));
  final _focus = FocusNode();
  late final RecentSearchesNotifier _recent;
  String _found = '';

  /// The suggestion list is hidden after a pick or a submit, until typing again.
  bool _dismissed = true;
  int _highlight = -1;

  @override
  void initState() {
    super.initState();
    _recent = ref.read(recentSearchesProvider.notifier);
    // A search that found something is worth remembering even if never submitted.
    ref.listenManual(searchResultsProvider, (_, next) {
      final r = next.value;
      if (r != null && !r.isEmpty) _found = ref.read(searchQueryProvider);
    });
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _recent.add(_found);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String q) {
    ref.read(searchQueryProvider.notifier).set(q);
    setState(() {
      _dismissed = false;
      _highlight = -1;
    });
  }

  void _setText(String q) {
    _controller.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    ref.read(searchQueryProvider.notifier).set(q);
    _focus.requestFocus();
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).set('');
    setState(() {
      _dismissed = true;
      _highlight = -1;
    });
    _focus.requestFocus();
  }

  /// Search for [q]: remember it and close the suggestions.
  void _search(String q) {
    _setText(q);
    _recent.add(q);
    setState(() {
      _dismissed = true;
      _highlight = -1;
    });
  }

  List<_Pick> _picks(String query, LibraryIndex index) {
    if (query.isEmpty || _dismissed || !_focus.hasFocus) return const [];
    final q = LibraryIndex.normalize(query);
    final recents = [
      for (final r in ref.read(recentSearchesProvider))
        if (LibraryIndex.normalize(r).contains(q) && LibraryIndex.normalize(r) != q) _Pick.recent(r),
    ].take(3);
    final matches = [for (final s in index.suggest(query)) _Pick.match(s)];
    return [...recents, ...matches];
  }

  void _move(int by, int count) {
    if (count == 0) return;
    setState(() => _highlight = (_highlight + 1 + by + count + 1) % (count + 1) - 1);
  }

  /// Esc: close the suggestions first, then clear what is typed, then leave.
  void _escape(bool open) {
    if (open) {
      setState(() {
        _dismissed = true;
        _highlight = -1;
      });
    } else if (_controller.text.isNotEmpty) {
      _clear();
    } else {
      goBack(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider).trim();
    final results = ref.watch(searchResultsProvider);
    ref.watch(recentSearchesProvider);
    // Watched from the start, so the index is loading (or loaded from the saved
    // lists) by the time the first letter is typed.
    final index = ref.watch(libraryIndexProvider);
    final picks = _picks(query, index);
    final open = picks.isNotEmpty;
    final loading = query.isNotEmpty && results.isLoading;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _escape(open),
        if (open) ...{
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1, picks.length),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1, picks.length),
        },
      },
      child: PageFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchPill(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                onChanged: _typed,
                onSubmitted: (q) {
                  if (_highlight >= 0 && _highlight < picks.length) {
                    _search(picks[_highlight].text);
                  } else {
                    _search(q);
                  }
                },
                onClear: _clear,
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.fast),
                curve: Motion.curve(context, Motion.standard),
                alignment: Alignment.topLeft,
                child: open
                    ? _Suggestions(
                        picks: picks,
                        highlight: _highlight,
                        onPick: (p) => _search(p.text),
                        onFill: (p) {
                          _setText(p.text);
                          setState(() => _highlight = -1);
                        },
                      )
                    : const SizedBox(width: double.infinity),
              ),
              // A squiggle ripples under the field while a search is on its way.
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
                child: SquiggleLoader(active: loading),
              ),
              if (query.isEmpty)
                _Recent(onPick: _search)
              else
                results.when(
                  data: (r) => _Results(results: r, query: query),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: ErrorPanel(error: e, onRetry: () => ref.invalidate(searchResultsProvider)),
                  ),
                  // Old results stay up while a new search is on its way, but an empty
                  // answer to an earlier query never shows as "No results" for this one.
                  loading: () => results.hasValue && !results.requireValue.isEmpty
                      ? _Results(results: results.requireValue, query: query)
                      : const _Searching(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dropdown under the field.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.picks, required this.highlight, required this.onPick, required this.onFill});

  final List<_Pick> picks;
  final int highlight;
  final ValueChanged<_Pick> onPick;
  final ValueChanged<_Pick> onFill;

  static IconData _icon(_Pick p) => switch (p.suggestion?.kind) {
        null => Icons.history_rounded,
        SuggestionKind.artist => Icons.person_rounded,
        SuggestionKind.album => Icons.album_rounded,
        SuggestionKind.song => Icons.music_note_rounded,
      };

  static String _kind(SuggestionKind k) => switch (k) {
        SuggestionKind.artist => 'Artist',
        SuggestionKind.album => 'Album',
        SuggestionKind.song => 'Song',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxWidth: 720),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, p) in picks.indexed)
              Pressable(
                onTap: () => onPick(p),
                semanticLabel: p.isRecent ? 'Recent search ${p.text}' : '${p.text}, ${_kind(p.suggestion!.kind)}',
                builder: (context, s) {
                  final on = s.hovered || i == highlight;
                  final sug = p.suggestion;
                  return AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    decoration: BoxDecoration(
                      color: on ? scheme.surfaceContainerHighest : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Icon(_icon(p), size: 22, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Highlighted(
                                text: p.text,
                                start: sug?.matchStart ?? -1,
                                length: sug?.matchLength ?? 0,
                                style: text.bodyLarge,
                              ),
                              if (sug != null)
                                Text(
                                  '${_kind(sug.kind)} · ${sug.subtitle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        // Puts the suggestion in the field without searching, like Google's arrow.
                        IconButton(
                          tooltip: 'Use this search',
                          visualDensity: VisualDensity.compact,
                          iconSize: 20,
                          onPressed: () => onFill(p),
                          icon: const Icon(Icons.north_west_rounded),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// [text] with the part that matched what was typed in bold.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.start, required this.length, required this.style});

  final String text;
  final int start;
  final int length;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final from = start.clamp(0, text.length);
    final to = (start + length).clamp(from, text.length);
    if (start < 0 || to == from) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, from)),
          TextSpan(
            text: text.substring(from, to),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text.substring(to)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Recent extends ConsumerWidget {
  const _Recent({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 22),
        child: EmptyPanel(
          icon: Icons.search_rounded,
          title: 'Search your library',
          message: 'Find artists, albums and songs. Press Ctrl+K or / from anywhere to jump here.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent searches',
          trailing: TextButton(onPressed: ref.read(recentSearchesProvider.notifier).clear, child: const Text('Clear')),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final q in recent)
              Pressable(
                onTap: () => onPick(q),
                semanticLabel: 'Search for $q',
                builder: (context, s) => Container(
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  height: 40,
                  decoration: BoxDecoration(
                    color: s.hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(q, style: text.bodyMedium),
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: () => ref.read(recentSearchesProvider.notifier).remove(q),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.results, required this.query});

  final SearchResults results;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 22),
        child: EmptyPanel(
          icon: Icons.search_off_rounded,
          title: 'No results for "$query"',
          message: 'Check the spelling, or try fewer words.',
        ),
      );
    }
    final player = ref.read(playbackProvider.notifier);
    var stagger = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (results.artists.isNotEmpty) ...[
          const SectionHeader(title: 'Artists', action: null),
          Wrap(
            spacing: _SearchPageState._gap,
            runSpacing: _SearchPageState._gap,
            children: [
              for (final a in results.artists) StaggerIn(index: stagger++, child: ArtistCard(artist: a, size: 132)),
            ],
          ),
        ],
        if (results.albums.isNotEmpty) ...[
          const SectionHeader(title: 'Albums', action: null),
          Wrap(
            spacing: _SearchPageState._gap,
            runSpacing: _SearchPageState._gap,
            children: [
              for (final a in results.albums) StaggerIn(index: stagger++, child: AlbumCard(album: a, size: 156)),
            ],
          ),
        ],
        if (results.tracks.isNotEmpty) ...[
          const SectionHeader(title: 'Songs', action: null),
          for (final (i, t) in results.tracks.indexed)
            StaggerIn(
              index: i < 12 ? i : 0,
              child: SongRow(track: t, onPlay: () => player.playTracks(results.tracks, index: i)),
            ),
        ],
      ],
    );
  }
}

/// Placeholder rows while the first results of a search load.
class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SkeletonBox(height: 52, radius: 22),
            ),
        ],
      ),
    );
  }
}
