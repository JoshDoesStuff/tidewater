import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/widgets/effects/glyph_run.dart';

void main() {
  testWidgets('animated text is baked at the pixel ratio times the scale applied above it', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget host(double scale) => MaterialApp(
          home: Center(
            child: Transform.scale(
              scale: scale,
              child: GlyphRun(
                text: 'see you later',
                style: const TextStyle(fontSize: 40),
                state: (i) => (pop: 1.0, opacity: 1.0),
              ),
            ),
          ),
        );
    double bakedAt() => tester.renderObject<RenderGlyphRun>(find.byType(GlyphRunLeaf)).sheet.dpr;

    await tester.pumpWidget(host(1));
    await tester.pump();
    expect(bakedAt(), 1);

    // The canvas is stretched 1.5x (the window got bigger than the design): the
    // text must be baked finer or it looks soft.
    await tester.pumpWidget(host(1.5));
    await tester.pump();
    await tester.pump();
    expect(bakedAt(), greaterThanOrEqualTo(1.5));

    // And a pixel-ratio change (a new monitor) rebakes too.
    tester.view.devicePixelRatio = 2;
    await tester.pump();
    await tester.pump();
    expect(bakedAt(), greaterThanOrEqualTo(3));
  });
}
