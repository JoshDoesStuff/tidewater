import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/selection.dart';
import 'package:tidewater/ui/pages/widgets/song_row.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('the Genres tab lists genres with their counts, and one opens its albums', (tester) async {
    final c = await pumpApp(tester);
    c.read(libraryTabProvider.notifier).set(LibraryTab.genres);
    c.read(routerProvider).go('/library');
    await advance(tester, const Duration(seconds: 2));
    expect(find.text('Electronic'), findsOneWidget);
    expect(find.text('4 albums · 6 songs'), findsOneWidget);
    await tester.tap(find.text('Electronic'));
    await advance(tester, const Duration(seconds: 2));
    expect(c.read(routerProvider).state.uri.path, '/genre/Electronic');
    expect(find.text('4 albums'), findsOneWidget);
    expect(find.text('Night Transit'), findsWidgets);
    expect(find.text('Glass Orchard'), findsNothing, reason: 'that one is Indie');
    await tester.tap(find.text('Play'));
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(playbackProvider).queue.length, 6);
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('a click on the empty part of a song row picks it while songs are picked, and names are links only on the words', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/liked');
    await advance(tester, const Duration(seconds: 2));
    final row = find.byType(SongRow).first;
    final rect = tester.getRect(row);
    c.read(selectionProvider.notifier).toggle(fakeTracks[3]);
    await advance(tester, const Duration(milliseconds: 300));
    // Right in the middle, where the album name's cell is.
    await tester.tapAt(Offset(rect.center.dx + 60, rect.center.dy));
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(routerProvider).state.uri.path, '/liked', reason: 'did not open an album');
    expect(c.read(selectionProvider).length, 2);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });
}
