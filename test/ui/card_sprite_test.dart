import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/perf_flags.dart';
import 'package:tidewater/ui/pages/widgets/album_card.dart';
import 'package:tidewater/ui/widgets/art_tile.dart';
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
    // A card becomes one picture soon after it is built (even before its cover is in).
    await advance(tester, const Duration(seconds: 2));
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

  testWidgets('cards past the frame budget show a stand-in and are built over the next frames', (tester) async {
    final c = await pumpApp(tester);
    PerfFlags.instance.cardBudget = true;
    MediaCard.firstBuildsPerFrame = 2;
    addTearDown(() => MediaCard.firstBuildsPerFrame = 24);
    c.read(routerProvider).go('/library');
    await tester.pump();
    await tester.pump();
    final cards = find.byType(AlbumCard).evaluate().length;
    final real = find.descendant(of: find.byType(AlbumCard), matching: find.byType(ArtTile)).evaluate().length;
    expect(cards, greaterThan(4));
    expect(real, lessThan(cards), reason: 'some are still stand-ins');
    expect(find.text(fakeAlbums.first.title), findsWidgets, reason: 'a stand-in already shows the title');
    await advance(tester, const Duration(seconds: 2));
    expect(find.descendant(of: find.byType(AlbumCard), matching: find.byType(ArtTile)).evaluate().length,
        find.byType(AlbumCard).evaluate().length,
        reason: 'all built by now');
    await disposeApp(tester);
  });
}
