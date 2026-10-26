import 'dart:async';

import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/session_persistence.dart';
import 'package:tidewater/core/models/server_play_queue.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  final placeholder = find.byKey(const ValueKey('continue-placeholder'));

  testWidgets('while the saved queue is still being looked for, a placeholder holds the place; the card replaces it', (tester) async {
    final api = FakeLibraryApi()
      ..queueGate = Completer<void>()
      ..serverQueue = ServerPlayQueue(
        tracks: fakeTracks.take(3).toList(),
        currentId: fakeTracks[1].id,
        position: const Duration(seconds: 30),
        changed: DateTime.now(),
      );
    final c = await pumpApp(tester, api: api);
    expect(c.read(queueRestoringProvider), isTrue);
    expect(placeholder, findsOneWidget, reason: 'the slot is reserved, not empty');
    expect(find.text('Continue listening'), findsNothing);

    api.queueGate!.complete();
    await advance(tester, const Duration(seconds: 2));
    expect(c.read(queueRestoringProvider), isFalse);
    expect(find.text('Continue listening'), findsOneWidget);
    expect(placeholder, findsNothing);
    await disposeApp(tester);
  });

  testWidgets('with nothing to continue, the placeholder goes away and leaves no card', (tester) async {
    final api = FakeLibraryApi()..queueGate = Completer<void>();
    final c = await pumpApp(tester, api: api);
    expect(placeholder, findsOneWidget);
    api.queueGate!.complete();
    await advance(tester, const Duration(seconds: 2));
    expect(c.read(queueRestoringProvider), isFalse);
    expect(placeholder, findsNothing);
    expect(find.text('Continue listening'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('a server that never answers does not hold the place forever', (tester) async {
    final api = FakeLibraryApi()..queueGate = Completer<void>();
    final c = await pumpApp(tester, api: api);
    await advance(tester, const Duration(seconds: 6));
    expect(c.read(queueRestoringProvider), isFalse, reason: 'gives up after the 4 second limit');
    expect(placeholder, findsNothing);
    await disposeApp(tester);
  });
}
