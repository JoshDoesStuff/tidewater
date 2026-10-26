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
  return ListCache(directory: () async => Directory('${(await root()).path}${Platform.pathSeparator}$folder'));
});

/// An index over the library's artists, albums and songs for autosuggest. It
/// grows as the lists load (from the saved copy first), and exists only while
/// something watches it, so the full song list is not loaded for nothing.
final libraryIndexProvider = Provider.autoDispose<LibraryIndex>((ref) {
  final albums = ref.watch(libraryAlbumsProvider(LibrarySort.recentlyAdded)).value?.albums ?? const [];
  final artists = ref.watch(artistsProvider).value ?? const [];
  final songs = ref.watch(libraryAllSongsProvider).value?.songs ?? const [];
  return LibraryIndex(artists: artists, albums: albums, songs: songs);
});
