import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('the mouse wheel glides to where it is going instead of jumping there', (tester) async {
    final api = FakeLibraryApi();
    api.playlistSongs['pl-1'] = [for (var i = 0; i < 60; i++) fakeTracks[i % fakeTracks.length]];
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/playlist/pl-1');
    await advance(tester, const Duration(seconds: 2));
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, 0);

    final at = tester.getCenter(find.byType(Scrollable).first);
    tester.binding.handlePointerEvent(PointerAddedEvent(position: at, kind: PointerDeviceKind.mouse));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, kind: PointerDeviceKind.mouse, scrollDelta: const Offset(0, 300)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final early = position.pixels;
    expect(early, greaterThan(0), reason: 'it has started');
    expect(early, lessThan(300), reason: 'but has not jumped the whole way');
    await tester.pump(const Duration(milliseconds: 600));
    expect(position.pixels, closeTo(300, 1), reason: 'and gets there');

    // Notches in a row add up.
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, kind: PointerDeviceKind.mouse, scrollDelta: const Offset(0, 100)));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, kind: PointerDeviceKind.mouse, scrollDelta: const Offset(0, 100)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
    expect(position.pixels, closeTo(500, 1));
    await advance(tester, const Duration(seconds: 1));
    await disposeApp(tester);
  });
}
