import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/ui/pages/widgets/song_row.dart';
import 'package:tidewater/ui/widgets/heart_button.dart';

import '../support/finders.dart';
import '../support/pump.dart';

void main() {
  testWidgets('a song row ends with the heart, then the length, then the menu dots', (tester) async {
    final c = await pumpApp(tester);
    c.read(libraryTabProvider.notifier).set(LibraryTab.songs);
    c.read(routerProvider).go('/library');
    await advance(tester, const Duration(seconds: 2));
    final row = find.byType(SongRow).first;
    final heart = tester.getCenter(find.descendant(of: row, matching: find.byType(HeartButton))).dx;
    final length = tester.getCenter(find.descendant(of: row, matching: find.text('3:20'))).dx;
    final more = tester.getCenter(find.descendant(of: row, matching: byHint('More'))).dx;
    expect(heart, lessThan(length));
    expect(length, lessThan(more));
    await disposeApp(tester);
  });

  testWidgets('album names are centered in their column, so a one-character album sits under the middle of a long one', (tester) async {
    final c = await pumpApp(tester);
    c.read(libraryTabProvider.notifier).set(LibraryTab.songs);
    c.read(routerProvider).go('/library');
    await advance(tester, const Duration(seconds: 2));
    final rows = find.byType(SongRow);
    double centerOf(int i) {
      final album = tester.widget<SongRow>(rows.at(i)).track.albumTitle;
      return tester.getCenter(find.descendant(of: rows.at(i), matching: find.text(album))).dx;
    }

    final a = centerOf(0);
    final b = centerOf(1);
    expect(tester.widget<SongRow>(rows.at(0)).track.albumTitle, isNot(tester.widget<SongRow>(rows.at(1)).track.albumTitle));
    expect((a - b).abs(), lessThan(1.5), reason: 'both are centered on the same line');
    await disposeApp(tester);
  });
}
