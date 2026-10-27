import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/core/models/album.dart';
import 'package:tidewater/ui/pages/widgets/album_card.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('cards built ahead of the scroll wait off screen, and animate in when they scroll into view', (tester) async {
    final albums = [
      for (var i = 0; i < 200; i++)
        Album(id: 'x$i', title: 'Album $i', artist: 'Artist $i', artistId: 'ar$i', coverArt: 'cv$i', songCount: 1, duration: const Duration(minutes: 3)),
    ];
    final c = await pumpApp(tester, api: FakeLibraryApi(albums: albums));
    c.read(routerProvider).go('/library');
    await advance(tester, const Duration(seconds: 3));

    final viewport = tester.getRect(find.byType(Scrollable).first);
    // A card that is built (in the area made ahead of the scroll) but below the window.
    final offScreen = find.byType(AlbumCard, skipOffstage: false).evaluate().map((e) => e.widget as AlbumCard).firstWhere(
          (w) => tester.getRect(find.byWidget(w, skipOffstage: false)).top > viewport.bottom,
        );
    double opacityOf(AlbumCard w) {
      final o = find.ancestor(of: find.byWidget(w, skipOffstage: false), matching: find.byType(Opacity, skipOffstage: false));
      return o.evaluate().isEmpty ? 1 : tester.widget<Opacity>(o.first).opacity;
    }

    expect(opacityOf(offScreen), 0, reason: 'its entrance has not played off screen');

    // Bring it into view.
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    position.jumpTo(position.pixels + tester.getRect(find.byWidget(offScreen, skipOffstage: false)).top - viewport.top - 100);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 150));
    final midway = opacityOf(offScreen);
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1), reason: 'it is animating in now');
    await advance(tester, const Duration(seconds: 1));
    expect(opacityOf(offScreen), 1);
    await disposeApp(tester);
  });
}
