import 'dart:async';

import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/cover_cache.dart';
import 'cover_providers.dart';
import 'library_providers.dart';
import 'search_providers.dart';
import 'session_providers.dart';
import 'ui_providers.dart';

/// Asks the server for everything again, for a library that changed while the
/// app was open (new songs or albums, a new playlist, an edited tag): the
/// album, song, artist and playlist lists, Home's rows, liked songs, open
/// album, artist and playlist pages, and search results. Each list shows what
/// it has while the new one loads, then swaps it in (and saves it).
///
/// These are closures over the provider container, not the widget, so they keep
/// working after the Settings page is left.
final refreshLibraryProvider = Provider<void Function({bool announce})>((ref) {
  return ({bool announce = true}) {
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
    if (announce) ref.read(toastProvider.notifier).show('Refreshing the library…');
  };
});

/// Deletes the saved covers so they are downloaded again (a cover that was
/// replaced on the server under the same id). The next screens load them fresh.
final clearCoverCacheProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final store = ref.read(coverCacheProvider);
    if (store is CoverCache) await store.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    ref.read(toastProvider.notifier).show('Covers cleared. They download again as you browse.');
  };
});

/// Tells the server to scan its music folders (admin accounts only), waits for
/// it to finish, then refreshes the library so the new music shows up.
final scanServerProvider = Provider<Future<void> Function()>((ref) {
  var running = false;
  return () async {
    if (running) return;
    running = true;
    final toast = ref.read(toastProvider.notifier);
    try {
      final api = ref.read(apiProvider);
      var status = await api.startScan();
      toast.show('The server is scanning its music folders…');
      final giveUp = DateTime.now().add(const Duration(minutes: 20));
      while (status.scanning && DateTime.now().isBefore(giveUp)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        status = await api.getScanStatus();
      }
      ref.read(refreshLibraryProvider)(announce: false);
      toast.show('The scan finished (${status.count} songs). Refreshing the library…');
    } on ApiException catch (e) {
      // Navidrome answers "not authorized" (code 50) to accounts that are not admins.
      toast.show(e.code == 50 || e.kind == ApiErrorKind.badCredentials ? 'Only an admin account can start a scan.' : e.message, error: true);
    } catch (_) {
      toast.show('Couldn\'t ask the server to scan.', error: true);
    } finally {
      running = false;
    }
  };
});
