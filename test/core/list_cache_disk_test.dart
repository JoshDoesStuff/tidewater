import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/api/list_cache.dart';

void main() {
  test('a list is saved, read back, and not rewritten when nothing changed', () async {
    final dir = await Directory.systemTemp.createTemp('tidewater_lists');
    addTearDown(() => dir.delete(recursive: true));
    final cache = ListCache(directory: () async => dir);
    final items = [
      {'id': 'a', 'name': 'Ä'},
      {'id': 'b', 'name': '日本語'},
    ];
    expect(await cache.read('albums'), isNull);

    await cache.write('albums', items);
    expect(await cache.read('albums'), items);

    final file = File('${dir.path}${Platform.pathSeparator}albums.json');
    final first = await file.lastModified();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await cache.write('albums', items);
    expect(await file.lastModified(), first, reason: 'the same list is not written again');

    await cache.write('albums', [...items, {'id': 'c'}]);
    expect((await cache.read('albums'))!.length, 3);
    expect(await file.lastModified(), isNot(first));
    expect(dir.listSync().where((e) => e.path.endsWith('.tmp')), isEmpty, reason: 'no half-written files left');
  });

  test('an unreadable file counts as no cache', () async {
    final dir = await Directory.systemTemp.createTemp('tidewater_lists');
    addTearDown(() => dir.delete(recursive: true));
    File('${dir.path}${Platform.pathSeparator}songs.json').writeAsStringSync('{ not json');
    expect(await ListCache(directory: () async => dir).read('songs'), isNull);
  });
}
