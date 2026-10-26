import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/shell/close_guard.dart';
import 'package:tidewater/ui/widgets/squiggle_loader.dart';

GlobalKey<State<CloseGuard>> key = GlobalKey();

Future<void> _pump(WidgetTester tester, {required Future<void> Function() save, required void Function() closed}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: CloseGuard(
          key: key,
          save: save,
          onClosed: () async => closed(),
          child: const Scaffold(body: Text('app')),
        ),
      ),
    ),
  );
}

Future<void> _close() => (key.currentState! as dynamic).close() as Future<void>;

void main() {
  testWidgets('a quick save closes the window without a flash of the wrapping up screen', (tester) async {
    var closed = 0;
    await _pump(tester, save: () async {}, closed: () => closed++);
    final done = _close();
    await tester.pump(const Duration(milliseconds: 50));
    await done;
    expect(closed, 1);
    expect(find.text('Wrapping up…'), findsNothing);
  });

  testWidgets('a slow save shows "Wrapping up…" with a squiggle, then closes when it finishes', (tester) async {
    final gate = Completer<void>();
    var closed = 0;
    await _pump(tester, save: () => gate.future, closed: () => closed++);
    final done = _close();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Wrapping up…'), findsNothing, reason: 'not yet: it may finish in a blink');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Wrapping up…'), findsOneWidget);
    expect(find.text('Saving your queue and place to the server'), findsOneWidget);
    expect(find.byType(SquiggleLoader), findsOneWidget);
    expect(closed, 0, reason: 'still waiting for the server');

    gate.complete();
    await done;
    expect(closed, 1);
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
    await first;
    expect(saves, 1);
    expect(closed, 1);
  });
}
