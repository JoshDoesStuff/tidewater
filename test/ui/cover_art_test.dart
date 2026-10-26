import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/cover_providers.dart';
import 'package:tidewater/core/api/cover_cache.dart';
import 'package:tidewater/ui/widgets/cover_art.dart';

/// A 1x1 red PNG.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==');

class _Covers implements CoverStore {
  _Covers({this.has = true});

  final bool has;

  @override
  Future<Uint8List> get(String id, {int size = 300}) async {
    if (!has) throw StateError('no cover');
    return Uint8List.fromList(_png);
  }
}

Finder get placeholder => find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PlaceholderPainter');

Widget app(CoverStore store, String? art) => ProviderScope(
      overrides: [coverCacheProvider.overrideWithValue(store)],
      child: MaterialApp(home: SizedBox(width: 100, height: 100, child: CoverArt(coverArt: art, seedKey: 'a', resolution: 150))),
    );

void main() {
  testWidgets('the gradient shows while the cover loads and is dropped once it is fully in', (tester) async {
    final store = _Covers();
    await tester.pumpWidget(app(store, 'cv'));
    expect(placeholder, findsOneWidget, reason: 'nothing loaded yet');
    await tester.runAsync(() async {
      // Let the image decode (real async work).
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Image), findsOneWidget);
    expect(placeholder, findsOneWidget, reason: 'still fading in: the gradient is needed underneath');
    await tester.pump(const Duration(milliseconds: 500));
    expect(placeholder, findsNothing, reason: 'fully covered: nothing to paint underneath');
  });

  testWidgets('an album without a cover keeps its gradient', (tester) async {
    await tester.pumpWidget(app(_Covers(), null));
    await tester.pump(const Duration(seconds: 1));
    expect(placeholder, findsOneWidget);
  });

  testWidgets('a cover that fails to load keeps its gradient', (tester) async {
    await tester.pumpWidget(app(_Covers(has: false), 'cv'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(seconds: 1));
    expect(placeholder, findsOneWidget);
  });

  test('placeholder colors are stable per key and differ between keys', () {
    expect(placeholderColors('x'), placeholderColors('x'));
    expect(placeholderColors('x'), isNot(placeholderColors('y')));
  });

  test('many artists without covers still look varied', () {
    final pairs = {for (var i = 0; i < 60; i++) placeholderColors('artist-$i')};
    expect(pairs.length, 60);
  });

}
