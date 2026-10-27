import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/cover_cache.dart';
import '../../core/api/list_cache.dart';
import '../../core/search/library_index.dart';
import 'library_providers.dart';
import 'session_providers.dart';

/// Where saved lists live. Tests override this (or [listStoreProvider]).
final listRootProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationCacheDirectory();
      return Directory('${base.path}${Platform.pathSeparator}lists');
    });

/// The saved library lists for the signed-in server (its own sub-folder).
final listStoreProvider = Provider<ListStore>((ref) {
  final config = ref.watch(sessionProvider);
  if (config == null) return MemoryListStore();
  final root = ref.watch(listRootProvider);
  final folder = CoverCache.serverFolder(config.baseUrl);
  final legacy = CoverCache.legacyServerFolder(config.baseUrl);
  return ListCache(directory: () async {
    final base = (await root()).path;
    final dir = Directory('$base${Platform.pathSeparator}$folder');
    // Lists saved under the old folder name (the whole URL) move over once.
    final old = Directory('$base${Platform.pathSeparator}$legacy');
    if (legacy != folder && !await dir.exists() && await old.exists()) {
      try {
        await old.rename(dir.path);
      } on FileSystemException {
        // Fetched again instead.
      }
    }
    return dir;
  });
});

/// An index over the library's artists, albums and songs for autosuggest. It
/// grows as the lists load (from the saved copy first), and exists only while
/// something watches it, so the full song list is not loaded for nothing.
// Not used by the UI right now (the autosuggest dropdown was taken out); kept for later.
final libraryIndexProvider = Provider.autoDispose<LibraryIndex>((ref) {
  final albums = ref.watch(libraryAlbumsProvider(LibrarySort.recentlyAdded)).value?.albums ?? const [];
  final artists = ref.watch(artistsProvider).value ?? const [];
  final songs = ref.watch(libraryAllSongsProvider).value?.songs ?? const [];
  return LibraryIndex(artists: artists, albums: albums, songs: songs);
});

/// Saved lists that were just refreshed from the server (by Refresh or Scan in
/// Settings): the provider that loads one reads it from the fresh copy and skips
/// asking the server a second time. Each name is used up once.
class FreshListsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(Iterable<String> names) => state = {...state, ...names};

  /// True once for a name that was just refreshed.
  bool consume(String name) {
    if (!state.contains(name)) return false;
    state = {...state}..remove(name);
    return true;
  }
}

final freshListsProvider = NotifierProvider<FreshListsNotifier, Set<String>>(FreshListsNotifier.new);
