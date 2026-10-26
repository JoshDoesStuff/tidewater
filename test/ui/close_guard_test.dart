import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/shell/close_guard.dart';
import 'package:tidewater/ui/widgets/squiggle_loader.dart';

GlobalKey<State<CloseGuard>> key = GlobalKey();

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function() save,
  required void Function() closed,
  bool always = false,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: CloseGuard(
          key: key,
          save: save,
          alwaysShow: always,
          onClosed: () async => closed(),
          child: const Scaffold(body: Text('app')),
        ),
      ),
    ),
  );
}

Future<void> _close() => (key.currentState! as dynamic).close() as Future<void>;

void main() {
  group('by default', () {
    testWidgets('a quick save closes the window at once, with no flash of the wrapping up screen', (tester) async {
      var closed = 0;
      await _pump(tester, save: () async {}, closed: () => closed++);
      final done = _close();
      await tester.pump(const Duration(milliseconds: 50));
      await done;
      expect(closed, 1);
      expect(find.text('Wrapping up…'), findsNothing);
    });

    testWidgets('a save that takes a while shows "Wrapping up…" after a moment, until it finishes', (tester) async {
      final gate = Completer<void>();
      var closed = 0;
      await _pump(tester, save: () => gate.future, closed: () => closed++);
      final done = _close();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Wrapping up…'), findsNothing, reason: 'not yet: it may finish in a blink');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Wrapping up…'), findsOneWidget);
      expect(find.text('Saving your queue and place to the server'), findsOneWidget);
      expect(find.byType(SquiggleLoader), findsOneWidget);
      expect(closed, 0, reason: 'still waiting for the server');

      gate.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await done;
      expect(closed, 1, reason: 'closes the moment the save is done');
    });

    testWidgets('a save that never answers gives up after two seconds and closes anyway', (tester) async {
      var closed = 0;
      await _pump(tester, save: () => Completer<void>().future, closed: () => closed++);
      final done = _close();
      await tester.pump(const Duration(seconds: 1));
      expect(closed, 0);
      await tester.pump(const Duration(seconds: 2));
      await done;
      expect(closed, 1);
    });

    testWidgets('a second close request while waiting does nothing extra', (tester) async {
      final gate = Completer<void>();
      var saves = 0;
      var closed = 0;
      await _pump(tester, save: () {
        saves++;
        return gate.future;
      }, closed: () => closed++);
      final first = _close();
      await _close();
      await tester.pump(const Duration(milliseconds: 50));
      gate.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await first;
      expect(saves, 1);
      expect(closed, 1);
    });
  });

  group('with "always show" on in Settings', () {
    testWidgets('even a quick save shows "Wrapping up…" at once and keeps it up for a moment before closing', (tester) async {
      var closed = 0;
      await _pump(tester, save: () async {}, closed: () => closed++, always: true);
      final done = _close();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Wrapping up…'), findsOneWidget, reason: 'there from the first moment, not after a delay');
      expect(find.byType(SquiggleLoader), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(closed, 0, reason: 'still showing: it stays for a short minimum');
      await tester.pump(const Duration(milliseconds: 400));
      await done;
      expect(closed, 1);
    });

    testWidgets('a slow save keeps the screen up until it finishes, then closes', (tester) async {
      final gate = Completer<void>();
      var closed = 0;
      await _pump(tester, save: () => gate.future, closed: () => closed++, always: true);
      final done = _close();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Wrapping up…'), findsOneWidget);
      expect(closed, 0, reason: 'still waiting for the server');

      gate.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await done;
      expect(closed, 1);
    });
  });
}
