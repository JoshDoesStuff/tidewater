import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/widgets/animated_glyphs.dart';

Widget _host(Widget child) => MaterialApp(home: Center(child: child));

void main() {
  for (final kind in GlyphKind.values) {
    testWidgets('$kind plays on hover and settles back to rest', (tester) async {
      Widget glyph(bool hovered) => _host(AnimatedGlyph(kind: kind, color: Colors.white, hovered: hovered));
      await tester.pumpWidget(glyph(false));
      await tester.pumpWidget(glyph(true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the volume speaker loads and scrubs between its three states', (tester) async {
    Widget glyph(int level) => _host(VolumeGlyph(level: level, color: Colors.white));
    await tester.pumpWidget(glyph(0));
    await tester.runAsync(() => IconComposition.load('assets/icons/volume.json'));
    await tester.pump();
    for (final level in [1, 2, 0]) {
      await tester.pumpWidget(glyph(level));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('the cast icon loads and plays on hover', (tester) async {
    Widget glyph(bool hovered) => _host(LottieGlyph(asset: 'assets/icons/cast.json', color: Colors.white, hovered: hovered));
    await tester.pumpWidget(glyph(false));
    await tester.runAsync(() => IconComposition.load('assets/icons/cast.json'));
    await tester.pump();
    await tester.pumpWidget(glyph(true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}
