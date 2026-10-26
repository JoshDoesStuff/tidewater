import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/list_cache.dart';
import 'package:tidewater/core/models/album.dart';

import '../support/fake_library.dart';
import '../support/test_app.dart';

Future<ProviderContainer> _container(MemoryListStore store, {FakeLibraryApi? api}) async {
  final overrides = await testOverrides(api: api, listStore: store);
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  const sort = LibrarySort.recentlyAdded;

  test('without a saved list the albums arrive from the server and are saved', () async {
    final store = MemoryListStore();
    final c = await _container(store);
    final seen = <List<String>>[];
    c.listen(libraryAlbumsProvider(sort), (_, next) {
      final v = next.value;
      if (v != null) seen.add([for (final a in v.albums) a.title]);
    }, fireImmediately: true);
    await _settle();
    expect(seen.last.length, fakeAlbums.length);
    expect(store.saved['albums_recentlyAdded']!.length, fakeAlbums.length);
  });

  test('with a saved list it shows at once, then the fresh one replaces it, and is saved', () async {
    final store = MemoryListStore()
      ..saved['albums_recentlyAdded'] = [const Album(id: 'old', title: 'Cached Album', artist: 'Old Artist').toJson()];
    final c = await _container(store);
    final seen = <List<String>>[];
    c.listen(libraryAlbumsProvider(sort), (_, next) {
      final v = next.value;
      if (v != null) seen.add([for (final a in v.albums) a.title]);
    }, fireImmediately: true);
    await _settle();
    expect(seen.first, ['Cached Album'], reason: 'the saved copy is the first thing shown');
    expect(seen.last.length, fakeAlbums.length, reason: 'the fresh list replaces it');
    expect(store.saved['albums_recentlyAdded']!.length, fakeAlbums.length);
  });

  test('with a saved list and the server down, the saved list stays', () async {
    final store = MemoryListStore()
      ..saved['artists'] = [
        {'id': 'x', 'name': 'Saved Artist', 'albumCount': 2},
      ];
    final api = FakeLibraryApi()..failWith = ApiException(ApiErrorKind.unreachable, 'offline');
    final c = await _container(store, api: api);
    c.listen(artistsProvider, (_, _) {}, fireImmediately: true);
    await _settle();
    final v = c.read(artistsProvider);
    expect(v.hasError, isFalse);
    expect(v.value!.single.name, 'Saved Artist');
  });

  test('the Library tab choice survives a restart', () async {
    final store = MemoryListStore();
    final c = await _container(store);
    expect(c.read(libraryTabProvider), LibraryTab.albums);
    c.read(libraryTabProvider.notifier).set(LibraryTab.playlists);
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.getString('library_tab'), 'playlists');
  });
}
