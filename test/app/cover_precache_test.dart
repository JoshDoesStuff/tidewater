import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/providers/cover_precache.dart';
import 'package:tidewater/app/providers/cover_providers.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/providers/session_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/core/api/cover_cache.dart';
import 'package:tidewater/core/models/album.dart';
import 'package:tidewater/core/models/track.dart';

import '../support/test_app.dart' show testServer;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('tw_precache'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(ProviderContainer, List<String>)> run({int songCount = 40}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fetched = <String>[];
    final cache = CoverCache(
      directory: () async => dir,
      fetch: (id, size) async {
        fetched.add(id);
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    final albums = [for (var i = 0; i < 30; i++) Album(id: 'a$i', title: 'A$i', artist: 'X', coverArt: 'al-$i')];
    final songs = [
      for (var i = 0; i < songCount; i++)
        Track(id: 's$i', title: 'S$i', artist: 'X', albumId: 'a$i', albumTitle: 'A', duration: Duration.zero, coverArt: i < 30 ? 'al-$i' : 'mf-$i'),
    ];
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialSessionProvider.overrideWithValue(testServer),
      coverCacheProvider.overrideWithValue(cache),
      libraryAlbumsProvider(LibrarySort.recentlyAdded).overrideWith((ref) => Stream.value(LibraryAlbums(albums, complete: true))),
      libraryAllSongsProvider.overrideWith((ref) => Stream.value(LibrarySongs(songs, complete: true))),
    ]);
    c.listen(coverPrecacheProvider, (_, _) {}, fireImmediately: true);
    for (var i = 0; i < 200 && !c.read(coverPrecacheProvider).finished; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return (c, fetched);
  }

  test('every album and song cover is saved once, and a second launch downloads nothing', () async {
    final (first, fetched) = await run();
    final p = first.read(coverPrecacheProvider);
    expect(p.finished, isTrue);
    expect(p.hasWork, isTrue, reason: 'covers missing: the progress shows');
    expect(p.total, 40, reason: 'song covers that are the album cover are not counted twice');
    expect(fetched.toSet().length, 40);
    expect(fetched.length, 40, reason: 'each written once');
    first.dispose();

    final (second, again) = await run();
    expect(second.read(coverPrecacheProvider).hasWork, isFalse, reason: 'all saved: nothing shows');
    expect(again, isEmpty, reason: 'covers on disk are only looked up, not fetched or rewritten');
    second.dispose();

    // New songs since (or an interrupted run): the progress shows again, for just those.
    final (third, more) = await run(songCount: 45);
    expect(third.read(coverPrecacheProvider).hasWork, isTrue);
    expect(third.read(coverPrecacheProvider).total, 5);
    expect(more, hasLength(5));
    third.dispose();
  });
}
