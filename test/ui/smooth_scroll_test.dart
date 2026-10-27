import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/perf_flags.dart';
import 'package:tidewater/ui/widgets/smooth_scroll.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  test('a drag or fling never moves the page faster than the wheel can (about 6000 px/s)', () {
    const physics = DeferringScrollPhysics(parent: ClampingScrollPhysics());
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 100000,
      pixels: 5000,
      viewportDimension: 1300,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );
    // A trackpad step of 1500 px is cut to at most a 30th of a second at full speed.
    expect(physics.applyPhysicsToUserOffset(metrics, 1500).abs(), lessThanOrEqualTo(DeferringScrollPhysics.maxSpeed / 30));
    expect(physics.applyPhysicsToUserOffset(metrics, -1500).abs(), lessThanOrEqualTo(DeferringScrollPhysics.maxSpeed / 30));
    expect(physics.applyPhysicsToUserOffset(metrics, 3), 3, reason: 'small steps pass unchanged');
    expect(physics.maxFlingVelocity, lessThanOrEqualTo(DeferringScrollPhysics.maxSpeed));
  });

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
    await advance(tester, const Duration(milliseconds: 3000));
    expect(position.pixels, closeTo(300, 1), reason: 'and gets there');

    // Notches in a row add up.
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, kind: PointerDeviceKind.mouse, scrollDelta: const Offset(0, 100)));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, kind: PointerDeviceKind.mouse, scrollDelta: const Offset(0, 100)));
    await tester.pump(const Duration(milliseconds: 16));
    await advance(tester, const Duration(milliseconds: 3000));
    expect(position.pixels, closeTo(500, 1));
    await advance(tester, const Duration(seconds: 1));
    await disposeApp(tester);
    });

  testWidgets('a fast glide tells pictures to wait, and a slow or finished one does not', (tester) async {
    // Off by default (it measured worse), but the mechanism should still work.
    PerfFlags.instance.deferCovers = true;
    addTearDown(() => PerfFlags.instance.deferCovers = false);
    final api = FakeLibraryApi();
    api.playlistSongs['pl-1'] = [for (var i = 0; i < 200; i++) fakeTracks[i % fakeTracks.length]];
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/playlist/pl-1');
    await advance(tester, const Duration(seconds: 2));
    final scrollable = find.byType(Scrollable).first;
    final at = tester.getCenter(scrollable);
    bool deferring() => Scrollable.recommendDeferredLoadingForContext(tester.element(find.byType(Text).first));

    tester.binding.handlePointerEvent(PointerAddedEvent(position: at, kind: PointerDeviceKind.mouse));
    // A small nudge: never fast enough to hold pictures back.
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, kind: PointerDeviceKind.mouse, scrollDelta: const Offset(0, 60)));
    var any = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      any |= deferring();
    }
    expect(any, isFalse);

    // A long fling of the wheel: the middle of the glide is too fast to load pictures.
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, kind: PointerDeviceKind.mouse, scrollDelta: const Offset(0, 3000)));
    any = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      any |= deferring();
    }
    expect(any, isTrue);
    await advance(tester, const Duration(seconds: 3));
    expect(deferring(), isFalse, reason: 'once it has stopped, pictures load');
    await disposeApp(tester);
  });
}
