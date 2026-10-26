import 'dart:async';

import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/cover_cache.dart';
import '../../core/api/library_api.dart';
import '../../core/models/album.dart';
import '../../core/models/track.dart';
import 'cover_providers.dart';
import 'library_providers.dart';
import 'list_cache_providers.dart';
import 'search_providers.dart';
import 'session_providers.dart';
import 'ui_providers.dart';

enum LibraryTaskKind { none, refresh, scan }

/// What Settings shows for the long jobs (Refresh, Scan): which one runs, the
/// line of status under it, and whether it ended badly.
class LibraryTask {
  const LibraryTask({
    this.kind = LibraryTaskKind.none,
    this.text = '',
    this.error = false,
    this.running = false,
  });

  final LibraryTaskKind kind;
  final String text;
  final bool error;
  final bool running;
}

class LibraryTaskNotifier extends Notifier<LibraryTask> {
  @override
  LibraryTask build() => const LibraryTask();

  void set(LibraryTask task) => state = task;
}

final libraryTaskProvider = NotifierProvider<LibraryTaskNotifier, LibraryTask>(
  LibraryTaskNotifier.new,
);

String _n(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

/// Asks the server for everything again, for a library that changed while the
/// app was open (new songs or albums, a new playlist, an edited tag): the
/// albums, songs, artists and playlists are fetched anew (with the count so far
/// shown in Settings), saved, and every screen reloads from them. Home's rows,
/// liked songs, open album, artist and playlist pages and search results are
/// reloaded too. Other album orders are fetched when you next pick them.
///
/// These are closures over the provider container, not the widget, so they keep
/// working after the Settings page is left.
final refreshLibraryProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (ref.read(libraryTaskProvider).running) return;
    await _refresh(ref, LibraryTaskKind.refresh);
  };
});

Future<void> _refresh(Ref ref, LibraryTaskKind kind) async {
  {
    void say(String text, {bool error = false, bool running = true}) => ref
        .read(libraryTaskProvider.notifier)
        .set(
          LibraryTask(kind: kind, text: text, error: error, running: running),
        );
    try {
      final api = ref.read(apiProvider);
      final store = ref.read(listStoreProvider);

      say('Asking the server for albums…');
      final albums = <Album>[];
      while (true) {
        final page = await api.getAlbumList(
          AlbumListType.newest,
          size: 500,
          offset: albums.length,
        );
        albums.addAll(page);
        say('Albums: ${_n(albums.length)}…');
        if (page.length < 500) break;
      }
      await store.write('albums_${LibrarySort.recentlyAdded.name}', [
        for (final a in albums) a.toJson(),
      ]);
      // The other orders are stale now: they load fresh when picked.
      for (final sort in LibrarySort.values) {
        if (sort != LibrarySort.recentlyAdded) {
          unawaited(store.write('albums_${sort.name}', const []));
        }
      }

      final songs = <Track>[];
      while (true) {
        final page = await api.getSongs(offset: songs.length, size: 500);
        songs.addAll(page);
        say('Songs: ${_n(songs.length)}…');
        if (page.length < 500) break;
      }
      await store.write('songs', [for (final t in songs) t.toJson()]);

      say('Artists…');
      final artists = await api.getArtists();
      await store.write('artists', [for (final a in artists) a.toJson()]);

      say('Playlists…');
      final playlists = await api.getPlaylists();
      await store.write('playlists', [for (final p in playlists) p.toJson()]);

      // Every screen reloads from what was just saved, without asking again.
      ref.read(freshListsProvider.notifier).add([
        'albums_${LibrarySort.recentlyAdded.name}',
        'songs',
        'artists',
        'playlists',
      ]);
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
      say(
        'Done: ${_n(albums.length)} albums, ${_n(songs.length)} songs, ${_n(artists.length)} artists, '
        '${_n(playlists.length)} playlists.',
        running: false,
      );
    } on ApiException catch (e) {
      say(
        e.isOffline
            ? 'Couldn\'t reach the server. Nothing was changed.'
            : e.message,
        error: true,
        running: false,
      );
    } catch (_) {}
  }
}

/// Deletes the saved covers so they are downloaded again (a cover that was
/// replaced on the server under the same id). The next screens load them fresh.
final clearCoverCacheProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final store = ref.read(coverCacheProvider);
    if (store is CoverCache) await store.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    ref
        .read(toastProvider.notifier)
        .show('Covers cleared. They download again as you browse.');
  };
});

/// Tells the server to scan its music folders (admin accounts only), shows how
/// many songs it has seen, waits for it to finish, then refreshes the library
/// so the new music shows up.
final scanServerProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (ref.read(libraryTaskProvider).running) return;
    void say(String text, {bool error = false, bool running = true}) => ref
        .read(libraryTaskProvider.notifier)
        .set(
          LibraryTask(
            kind: LibraryTaskKind.scan,
            text: text,
            error: error,
            running: running,
          ),
        );
    try {
      final api = ref.read(apiProvider);
      say('Asking the server to scan…');
      var status = await api.startScan();
      say('The server is scanning its music folders…');
      final giveUp = DateTime.now().add(const Duration(minutes: 20));
      while (status.scanning && DateTime.now().isBefore(giveUp)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        status = await api.getScanStatus();
        say('The server is scanning: ${_n(status.count)} songs seen so far…');
      }
      say(
        'The scan finished (${_n(status.count)} songs). Refreshing the library…',
      );
    } on ApiException catch (e) {
      // Navidrome answers "not authorized" (code 50) to accounts that are not admins.
      say(
        e.code == 50 || e.kind == ApiErrorKind.badCredentials
            ? 'Only an admin account can start a scan.'
            : e.message,
        error: true,
        running: false,
      );
      return;
    } catch (_) {
      say('Couldn\'t ask the server to scan.', error: true, running: false);
      return;
    }
    // The same status line carries on through the refresh.
    await _refresh(ref, LibraryTaskKind.scan);
  };
});
