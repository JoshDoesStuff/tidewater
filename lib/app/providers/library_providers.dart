import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/library_api.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../../core/models/track.dart';
import 'session_providers.dart';

/// Albums for a Home row (recently added, most played, recently played).
/// Refreshing keeps the old data on screen until the new list arrives.
final albumRowProvider = FutureProvider.family<List<Album>, AlbumListType>(
  (ref, type) => ref.watch(apiProvider).getAlbumList(type, size: 20),
);

/// How the Library grid is ordered. Sorting happens on the server so it is
/// right for libraries too big to load at once.
enum LibrarySort {
  recentlyAdded('Recently added', AlbumListType.newest),
  name('Album name', AlbumListType.alphabeticalByName),
  artist('Artist', AlbumListType.alphabeticalByArtist),
  mostPlayed('Most played', AlbumListType.frequent),
  recentlyPlayed('Recently played', AlbumListType.recent),
  year('Year', AlbumListType.byYear);

  const LibrarySort(this.label, this.type);
  final String label;
  final AlbumListType type;
}

/// Albums loaded so far for the current sort, and whether that is all of them.
class LibraryAlbums {
  const LibraryAlbums(this.albums, {required this.complete});

  final List<Album> albums;
  final bool complete;
}

/// Every album, loaded page by page: the first page quickly so the grid
/// appears, bigger pages after that until the server runs out. The grid
/// builds lazily, so thousands of albums cost memory for the metadata only.
final libraryAlbumsProvider = StreamProvider.family<LibraryAlbums, LibrarySort>((ref, sort) async* {
  final api = ref.watch(apiProvider);
  final all = <Album>[];
  while (true) {
    final size = all.isEmpty ? 120 : 500;
    final page = await api.getAlbumList(
      sort.type,
      size: size,
      offset: all.length,
      // Newest year first.
      fromYear: sort == LibrarySort.year ? 9999 : null,
      toYear: sort == LibrarySort.year ? 0 : null,
    );
    all.addAll(page);
    final done = page.length < size;
    yield LibraryAlbums(List.unmodifiable(all), complete: done);
    if (done) return;
  }
});

final artistsProvider = FutureProvider<List<Artist>>((ref) => ref.watch(apiProvider).getArtists());

final playlistsProvider = FutureProvider<List<Playlist>>((ref) => ref.watch(apiProvider).getPlaylists());

/// A value the UI picks and other screens can set (Home's "Show all" opens
/// the Library on the right tab and sort).
class PickNotifier<T> extends Notifier<T> {
  PickNotifier(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

enum LibraryTab {
  albums('Albums'),
  songs('Songs'),
  playlists('Playlists');

  const LibraryTab(this.label);
  final String label;
}

final libraryTabProvider =
    NotifierProvider<PickNotifier<LibraryTab>, LibraryTab>(() => PickNotifier(LibraryTab.albums));

final librarySortProvider =
    NotifierProvider<PickNotifier<LibrarySort>, LibrarySort>(() => PickNotifier(LibrarySort.recentlyAdded));

/// Genres the album grid is filtered to; empty shows everything.
final libraryGenreProvider = NotifierProvider<PickNotifier<Set<String>>, Set<String>>(() => PickNotifier<Set<String>>(const {}));

/// One album with its tracks (the album page).
final albumDetailProvider = FutureProvider.family<AlbumDetail, String>((ref, id) => ref.watch(apiProvider).getAlbum(id));

/// One artist with their albums (the artist page).
final artistDetailProvider = FutureProvider.family<ArtistDetail, String>((ref, id) => ref.watch(apiProvider).getArtist(id));

/// How the Songs tab is ordered (client-side: the server has no sorted
/// "all songs" call).
enum SongSort {
  title('Title'),
  artist('Artist'),
  album('Album');

  const SongSort(this.label);
  final String label;

  String _key(Track t) => (switch (this) {
        SongSort.title => t.title,
        SongSort.artist => t.artist,
        SongSort.album => t.albumTitle,
      })
          .toLowerCase();

  /// Sorted copy; ties fall back to title so the order is stable.
  List<Track> sorted(Iterable<Track> songs) => [...songs]..sort((a, b) {
        final c = _key(a).compareTo(_key(b));
        return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
}

final librarySongSortProvider = NotifierProvider<PickNotifier<SongSort>, SongSort>(() => PickNotifier(SongSort.title));

/// Songs loaded so far, and whether that is all of them.
class LibrarySongs {
  const LibrarySongs(this.songs, {required this.complete});

  final List<Track> songs;
  final bool complete;
}

/// Every song, loaded page by page (200 first, then 500 at a time) in the
/// server's order; [sortedSongsProvider] orders them for the list.
final libraryAllSongsProvider = StreamProvider<LibrarySongs>((ref) async* {
  final api = ref.watch(apiProvider);
  final all = <Track>[];
  while (true) {
    final size = all.isEmpty ? 200 : 500;
    final page = await api.getSongs(offset: all.length, size: size);
    all.addAll(page);
    final done = page.length < size;
    yield LibrarySongs(List.unmodifiable(all), complete: done);
    if (done) return;
  }
});

/// The loaded songs in the chosen order (keeps loading/error state).
final sortedSongsProvider = Provider<AsyncValue<LibrarySongs>>((ref) {
  final sort = ref.watch(librarySongSortProvider);
  return ref.watch(libraryAllSongsProvider).whenData((l) => LibrarySongs(sort.sorted(l.songs), complete: l.complete));
});
