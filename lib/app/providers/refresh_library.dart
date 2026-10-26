import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cover_cache.dart';
import 'cover_providers.dart';
import 'library_providers.dart';
import 'search_providers.dart';
import 'ui_providers.dart';

/// Asks the server for everything again, for a library that changed while the
/// app was open (new songs or albums, a new playlist, an edited tag): the
/// album, song, artist and playlist lists, Home's rows, liked songs, open
/// album, artist and playlist pages, and search results. Each list shows what
/// it has while the new one loads, then swaps it in (and saves it).
void refreshLibrary(WidgetRef ref) {
  ref
    ..invalidate(libraryAlbumsProvider)
    ..invalidate(libraryAllSongsProvider)
    ..invalidate(artistsProvider)
    ..invalidate(playlistsProvider)
    ..invalidate(albumRowProvider)
    ..invalidate(likedSongsProvider)
    ..invalidate(albumDetailProvider)
    ..invalidate(artistDetailProvider)
    ..invalidate(playlistDetailProvider)
    ..invalidate(searchResultsProvider);
  ref.read(toastProvider.notifier).show('Refreshing the library…');
}

/// Deletes the saved covers so they are downloaded again (a cover that was
/// replaced on the server under the same id). The next screens load them fresh.
Future<void> clearCoverCache(WidgetRef ref) async {
  final store = ref.read(coverCacheProvider);
  if (store is CoverCache) await store.clear();
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
  ref.read(toastProvider.notifier).show('Covers cleared. They download again as you browse.');
}
