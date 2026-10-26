import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/providers/search_providers.dart';
import '../../core/models/search_results.dart';
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

/// Search the library: artists, albums and songs for what is typed, or the
/// recent searches while nothing is. Keyboard first: `Ctrl+K` or `/` opens it
/// with the field focused, `Enter` remembers the search, `Esc` clears the field
/// and then leaves.
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

  @override
  void initState() {
    super.initState();
    _recent = ref.read(recentSearchesProvider.notifier);
    // A search that found something is worth remembering even if never submitted.
    ref.listenManual(searchResultsProvider, (_, next) {
      final r = next.value;
      if (r != null && !r.isEmpty) _found = ref.read(searchQueryProvider);
    });
  }

  @override
  void dispose() {
    _recent.add(_found);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _controller.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    ref.read(searchQueryProvider.notifier).set(q);
    _focus.requestFocus();
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).set('');
    _focus.requestFocus();
  }

  /// Esc: clear what is typed first, then leave the page.
  void _escape() {
    if (_controller.text.isNotEmpty) {
      _clear();
    } else {
      goBack(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider).trim();
    final results = ref.watch(searchResultsProvider);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
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
                onChanged: ref.read(searchQueryProvider.notifier).set,
                onSubmitted: (q) {
                  _recent.add(q);
                  _focus.requestFocus();
                },
                onClear: _clear,
              ),
              // The buffering squiggle runs under the field while a search is on its way.
              Padding(
                padding: const EdgeInsets.only(top: 14, left: 20, right: 20),
                child: SquiggleLoader(active: query.isNotEmpty && results.isLoading),
              ),
              if (query.isEmpty)
                _Recent(onPick: _setQuery)
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
              child: SongRow(track: t, siblings: results.tracks, onPlay: () => player.playTracks(results.tracks, index: i)),
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
