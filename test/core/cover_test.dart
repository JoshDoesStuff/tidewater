import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/cover_cache.dart';
import 'package:tidewater/core/color/cover_seed.dart';

Uint8List _bytes(int seed) => Uint8List.fromList(List.filled(64, seed));

/// Pixels of a flat-colored "cover".
List<int> _flat(int argb, [int n = 400]) => List.filled(n, argb);

double _hue(int argb) => Hct.fromInt(argb).hue;

void main() {
  group('CoverCache', () {
    late Directory dir;
    late List<(String, int)> fetched;

    CoverCache make({bool fail = false}) => CoverCache(
          directory: () async => dir,
          fetch: (id, size) async {
            fetched.add((id, size));
            if (fail) throw const ApiException(ApiErrorKind.notFound, 'no art');
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return _bytes(size == 300 ? 3 : 8);
          },
        );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tidewater_cover_test');
      fetched = [];
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('no more than twelve covers are fetched at once, and waiting ones go newest first', () async {
      var running = 0;
      var most = 0;
      final order = <String>[];
      final gates = <Completer<void>>[];
      final cache = CoverCache(
        directory: () async => dir,
        fetch: (id, size) async {
          running++;
          most = running > most ? running : most;
          order.add(id);
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
          running--;
          return _bytes(1);
        },
      );
      final all = [for (var i = 0; i < 16; i++) cache.get('c$i')];
      // Let the first ones reach the network.
      for (var i = 0; i < 20 && gates.length < 12; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(gates.length, 12);
      expect(most, 12);
      // Free them one by one: the queue drains from the newest request.
      while (gates.any((g) => !g.isCompleted)) {
        gates.firstWhere((g) => !g.isCompleted).complete();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future.wait(all);
      expect(most, 12);
      expect(order.sublist(12), ['c15', 'c14', 'c13', 'c12']);
    });

    test('second request is served from disk, even by a new cache object', () async {
      expect(await make().get('al-1_6600'), _bytes(3));
      expect(await make().get('al-1_6600'), _bytes(3));
      expect(fetched, [('al-1_6600', 300)]);
    });

    test('the same cover at two sizes is two files', () async {
      final c = make();
      expect(await c.get('x', size: 300), _bytes(3));
      expect(await c.get('x', size: 800), _bytes(8));
      expect(fetched, [('x', 300), ('x', 800)]);
      expect(dir.listSync().length, 2);
    });

    test('odd sizes snap to the buckets 150 / 300 / 800', () async {
      expect([for (final s in [64, 150, 151, 300, 301, 800, 2000]) CoverCache.bucket(s)], [150, 150, 300, 300, 800, 800, 800]);
      final c = make();
      await c.get('x', size: 280);
      await c.get('x', size: 300);
      expect(fetched, hasLength(1));
    });

    test('concurrent requests share one download', () async {
      final c = make();
      final results = await Future.wait([c.get('x'), c.get('x'), c.get('x')]);
      expect(results.every((b) => b.length == 64), isTrue);
      expect(fetched, hasLength(1));
    });

    test('a failed download is not cached and can be retried', () async {
      await expectLater(make(fail: true).get('x'), throwsA(isA<ApiException>()));
      expect(dir.existsSync() ? dir.listSync() : const [], isEmpty);
      expect(await make().get('x'), _bytes(3));
    });

    test('ids with odd characters stay inside the cache folder', () async {
      await make().get('../../evil/..\\x');
      expect(dir.listSync().single.path, startsWith(dir.path));
    });

    test('different servers get different folders', () {
      expect(CoverCache.serverFolder(Uri.parse('https://a.example.com')), isNot(CoverCache.serverFolder(Uri.parse('https://b.example.com'))));
      expect(CoverCache.serverFolder(Uri.parse('https://a.example.com')), CoverCache.serverFolder(Uri.parse('https://a.example.com')));
    });

    test('trim drops the least recently used files first', () async {
      final c = make();
      await c.get('old');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await c.get('new');
      await c.trim(100); // each file is 64 bytes
      final names = dir.listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(names.single, startsWith('new_'));
    });
  });

  group('seedFromPixels', () {
    test('a red cover seeds a red scheme', () async {
      final seed = await seedFromPixels(_flat(0xffd32f2f));
      expect(seed.muted, isFalse);
      final hue = _hue(seed.argb);
      expect(hue < 30 || hue > 330, isTrue, reason: 'hue $hue');
    });

    test('prefers the colorful part over a dull majority', () async {
      // 70 % gray, 30 % saturated blue: the app should still turn blue.
      final seed = await seedFromPixels([..._flat(0xff777777, 700), ..._flat(0xff1565c0, 300)]);
      expect(seed.muted, isFalse);
      expect(_hue(seed.argb), inInclusiveRange(230, 280));
    });

    test('gray art gives a muted seed instead of a random hue', () async {
      final seed = await seedFromPixels(_flat(0xff808080));
      expect(seed.muted, isTrue);
      expect(Hct.fromInt(seed.argb).chroma, lessThan(8));
    });

    test('black and white covers are muted too', () async {
      expect((await seedFromPixels([..._flat(0xff000000), ..._flat(0xffffffff)])).muted, isTrue);
      expect((await seedFromPixels(_flat(0xff101010))).muted, isTrue);
    });

    test('a small splash of color on a mostly black cover is quiet, not full strength', () async {
      // 97 % black, 3 % red (think pixel-art heart on a black cover).
      final seed = await seedFromPixels([..._flat(0xff000000, 970), ..._flat(0xffd32f2f, 30)]);
      expect(seed.muted, isTrue);
      final hue = _hue(seed.argb);
      expect(hue < 30 || hue > 330, isTrue, reason: 'it keeps the splash hue: $hue');
    });

    test('a warm gray cover (a photo of the moon) does not turn the app orange', () async {
      final seed = await seedFromPixels([..._flat(0xff8f8a82, 600), ..._flat(0xffd9d4cc, 300), ..._flat(0xff1a1816, 100)]);
      expect(seed.muted, isTrue);
    });

    test('transparent pixels are ignored', () async {
      final seed = await seedFromPixels([..._flat(0x00ff0000, 900), ..._flat(0xff2e7d32, 100)]);
      expect(seed.muted, isFalse);
      expect(_hue(seed.argb), inInclusiveRange(100, 160));
    });

    test('an empty or fully transparent image falls back to muted gray', () async {
      expect((await seedFromPixels(const [])).muted, isTrue);
      expect((await seedFromPixels(_flat(0x00000000))).muted, isTrue);
    });

    test('ids give stable, spread-out placeholder hues', () {
      expect(CoverSeed.fromKey('al-1'), CoverSeed.fromKey('al-1'));
      final hues = {for (var i = 0; i < 40; i++) (_hue(CoverSeed.fromKey('album-$i').argb) / 30).floor()};
      expect(hues.length, greaterThan(6));
    });
  });
}
