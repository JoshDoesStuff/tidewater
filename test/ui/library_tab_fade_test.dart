import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/library_providers.dart';

import '../support/pump.dart';

void main() {
  testWidgets('switching Library tabs fades the old one all the way out and the new one in', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/library');
    await advance(tester, const Duration(seconds: 3));
    double opacity() => ((tester.renderObject(find.byType(SliverAnimatedOpacity)) as dynamic).opacity as Animation<double>).value;

    final seen = <double>[];
    c.read(libraryTabProvider.notifier).set(LibraryTab.songs);
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      seen.add(opacity());
    }
    final low = seen.indexOf(seen.reduce((a, b) => a < b ? a : b));
    expect(seen[low], lessThan(.05), reason: 'the old tab is gone before the new one shows: $seen');
    final rising = seen.skip(low).where((o) => o > .05 && o < .95).length;
    expect(rising, greaterThanOrEqualTo(2), reason: 'and the new one fades in over several frames: $seen');
    expect(seen.last, 1);
    await advance(tester, const Duration(seconds: 3));
    await disposeApp(tester);
  });
}
