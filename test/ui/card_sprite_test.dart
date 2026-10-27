import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/perf_flags.dart';
import 'package:tidewater/ui/pages/widgets/album_card.dart';
import 'package:tidewater/ui/widgets/shapes/morph_shape.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('a resting card becomes one picture, and a hover brings the real card back', (tester) async {
    final c = await pumpApp(tester);
    PerfFlags.instance.sprites = true;
    c.read(routerProvider).go('/library');
    await advance(tester, const Duration(seconds: 2));
    final card = find.byType(AlbumCard).first;
    final title = fakeAlbums.first.title;
    // A new card is real while its cover loads; once it has settled it is drawn once.
    expect(find.descendant(of: card, matching: find.byType(RawImage)), findsNothing);
    await advance(tester, const Duration(seconds: 7));
    expect(find.descendant(of: card, matching: find.byType(RawImage)), findsOneWidget, reason: 'it rests as a picture');
    expect(find.descendant(of: card, matching: find.byType(MorphShape)), findsNothing);
    expect(tester.getSize(card).width, greaterThan(100), reason: 'and is the same size as before');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card) - const Offset(0, 20));
    await advance(tester, const Duration(milliseconds: 600));
    expect(find.descendant(of: card, matching: find.byType(MorphShape)), findsWidgets, reason: 'hovering makes the real card');
    expect(tester.widget<MorphShape>(find.descendant(of: card, matching: find.byType(MorphShape)).first).spin, greaterThan(0));
    expect(find.descendant(of: card, matching: find.text(title)), findsWidgets);

    await mouse.moveTo(const Offset(5, 5));
    await advance(tester, const Duration(seconds: 3));
    expect(find.descendant(of: card, matching: find.byType(RawImage)), findsOneWidget, reason: 'and it rests again');
    await mouse.removePointer();
    await disposeApp(tester);
  });
}
