import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/providers/cover_providers.dart';
import 'package:tidewater/app/providers/seed_store.dart';
import 'package:tidewater/core/api/cover_cache.dart';
import 'package:tidewater/core/color/cover_seed.dart';

import '../support/pump.dart';
import '../support/test_app.dart';

Future<SharedPreferences> prefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  test('remembers seeds, including muted ones, across restarts', () async {
    final p = await prefs();
    final a = SeedStore(p, saveDelay: const Duration(milliseconds: 10));
    a.put('s|c1', const CoverSeed(0xffd32f2f));
    a.put('s|c2', const CoverSeed(0xff808080, muted: true));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final b = SeedStore(p); // a new launch
    expect(b.get('s|c1'), const CoverSeed(0xffd32f2f));
    expect(b.get('s|c2'), const CoverSeed(0xff808080, muted: true));
    expect(b.get('s|nope'), isNull);
  });

  test('many writes in a burst become one save', () async {
    final p = await prefs();
    final s = SeedStore(p, saveDelay: const Duration(milliseconds: 30));
    for (var i = 0; i < 200; i++) {
      s.put('s|c$i', CoverSeed(0xff000000 + i));
    }
    expect(p.getString('cover_seeds'), isNull, reason: 'not yet');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(SeedStore(p).length, 200);
  });

  test('the oldest entries go first past the limit', () async {
    final s = SeedStore(await prefs(), saveDelay: const Duration(hours: 1));
    for (var i = 0; i < SeedStore.maxEntries + 10; i++) {
      s.put('s|c$i', const CoverSeed(0xff112233));
    }
    expect(s.length, SeedStore.maxEntries);
    expect(s.get('s|c0'), isNull);
    expect(s.get('s|c${SeedStore.maxEntries + 9}'), isNotNull);
  });

  test('a damaged cache is an empty one', () async {
    expect(SeedStore(await prefs({'cover_seeds': '{broken'})).length, 0);
    expect(SeedStore(await prefs({'cover_seeds': '[1,2]'})).length, 0);
    expect(SeedStore(await prefs({'cover_seeds': '{"a":5,"b":"xyz"}'})).get('b'), isNull);
  });

  testWidgets('a remembered cover needs no download or decoding at all', (tester) async {
    final key = '${CoverCache.serverFolder(testServer.baseUrl)}|cv-a0';
    // NoCovers (the test cover store) fails every download, so getting the
    // saved color back proves the cover was never asked for.
    final c = await pumpApp(tester, prefs: {
      'cover_seeds': jsonEncode({key: '${0xff2e7d32}'}),
    });
    final seed = await c.read(coverSeedProvider((albumId: 'a0', coverArt: 'cv-a0')).future);
    expect(seed, const CoverSeed(0xff2e7d32));
    await disposeApp(tester);
  });

  testWidgets('an unknown cover falls back to the album color and is not remembered', (tester) async {
    final c = await pumpApp(tester);
    final seed = await c.read(coverSeedProvider((albumId: 'a0', coverArt: 'cv-a0')).future);
    expect(seed, CoverSeed.fromKey('a0'));
    expect(c.read(seedStoreProvider).length, 0);
    await disposeApp(tester);
  });
}
