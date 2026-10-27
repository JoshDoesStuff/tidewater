import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/core/models/album.dart';
import 'package:tidewater/ui/pages/widgets/album_card.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('cards built ahead of the scroll wait off screen (drawn plainly), and rise in when they scroll into view', (tester) async {
    final albums = [
      for (var i = 0; i < 200; i++)
        Album(id: 'x$i', title: 'Album $i', artist: 'Artist $i', artistId: 'ar$i', coverArt: 'cv$i', songCount: 1, duration: const Duration(minutes: 3)),
    ];
    final c = await pumpApp(tester, api: FakeLibraryApi(albums: albums));
    c.read(routerProvider).go('/library');
    await advance(tester, const Duration(seconds: 3));

    final viewport = tester.getRect(find.byType(Scrollable).first);
    Finder cardOf(AlbumCard w) => find.byWidget(w, skipOffstage: false);
    // A card that is built (in the area made ahead of the scroll) but below the window.
    final offScreen = find.byType(AlbumCard, skipOffstage: false).evaluate().map((e) => e.widget as AlbumCard).firstWhere(
          (w) => tester.getRect(cardOf(w)).top > viewport.bottom,
        );
    // Not hidden at zero opacity while it waits: drawn, so it can become its resting picture early.
    expect(find.ancestor(of: cardOf(offScreen), matching: find.byType(Opacity, skipOffstage: false)), findsNothing);

    // Bring it into view, 100 px below the top.
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    position.jumpTo(position.pixels + tester.getRect(cardOf(offScreen)).top - viewport.top - 100);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getRect(cardOf(offScreen)).top - viewport.top;
    expect(midway, greaterThan(100.5), reason: 'it is rising into place: $midway');
    expect(midway, lessThan(120));
    await advance(tester, const Duration(seconds: 1));
    expect(tester.getRect(cardOf(offScreen)).top - viewport.top, closeTo(100, .5));
    await disposeApp(tester);
  });
}
