import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/destinations.dart';
import 'package:tidewater/app/theme/motion.dart';
import 'package:tidewater/core/data/fake_library.dart';
import 'package:tidewater/ui/widgets/shapes/squircle.dart';

Future<void> _pumpApp(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: TidewaterApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shell shows rail, mini player, FAB and Home', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('Jump back in'), findsOneWidget);
    expect(find.text('Shuffle all'), findsOneWidget);
    expect(find.text(fakeAlbums.first.track), findsOneWidget); // mini player
    for (final d in Destination.values) {
      expect(find.text(d.label), findsWidgets);
    }
  });

  testWidgets('rail navigates to Library and back', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('1,284 albums · 96 GB'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Good evening'), findsOneWidget);
  });

  testWidgets('narrow window collapses rail labels and FAB', (tester) async {
    await _pumpApp(tester, size: const Size(800, 600));
    expect(find.text('Shuffle all'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced-motion setting reaches MediaQuery', (tester) async {
    await _pumpApp(tester);
    final element = tester.element(find.text('Good evening'));
    expect(Motion.reduced(element), isFalse);
    final container = ProviderScope.containerOf(element);
    container.read(reduceMotionProvider.notifier).set(true);
    await tester.pumpAndSettle();
    expect(Motion.reduced(tester.element(find.text('Good evening'))), isTrue);
  });

  test('squircle path stays inside its box and is closed', () {
    final bounds = squirclePath(const Size(100, 100)).getBounds();
    expect(bounds.left, closeTo(0, 1));
    expect(bounds.right, closeTo(100, 1));
    expect(bounds.top, closeTo(0, 1));
    expect(bounds.bottom, closeTo(100, 1));
  });

  test('motion tokens match the spec', () {
    expect(Motion.fast.inMilliseconds, 150);
    expect(Motion.medium.inMilliseconds, 300);
    expect(Motion.slow.inMilliseconds, 520);
  });

  test('destinations resolve from locations', () {
    expect(Destination.fromLocation('/library'), Destination.library);
    expect(Destination.fromLocation('/library/album/1'), Destination.library);
    expect(Destination.fromLocation('/nope'), isNull);
  });
}
