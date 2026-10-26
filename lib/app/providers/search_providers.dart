import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/search_results.dart';
import 'library_providers.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

/// What is typed in the search field.
final searchQueryProvider = NotifierProvider<PickNotifier<String>, String>(() => PickNotifier<String>(''));

/// Results for the typed query: artists, albums and songs from `search3`. Waits
/// a moment after the last keystroke so typing "bohemian" is one request, not eight.
final searchResultsProvider = FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const SearchResults();
  var stale = false;
  ref.onDispose(() => stale = true);
  await Future<void>.delayed(const Duration(milliseconds: 250));
  if (stale) return const SearchResults();
  return ref.watch(apiProvider).search(query, artistCount: 12, albumCount: 18, songCount: 30);
});

/// The last searches that were submitted (newest first), remembered between
/// launches.
class RecentSearchesNotifier extends Notifier<List<String>> {
  static const key = 'recent_searches';
  static const max = 10;

  @override
  List<String> build() => ref.watch(sharedPreferencesProvider).getStringList(key) ?? const [];

  void add(String query) {
    final q = query.trim();
    if (q.length < 2) return;
    _save([q, ...state.where((s) => s.toLowerCase() != q.toLowerCase())].take(max).toList());
  }

  void remove(String query) => _save([...state.where((s) => s != query)]);

  void clear() => _save(const []);

  void _save(List<String> value) {
    state = value;
    ref.read(sharedPreferencesProvider).setStringList(key, value);
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearchesNotifier, List<String>>(RecentSearchesNotifier.new);
