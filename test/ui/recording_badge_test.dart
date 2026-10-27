import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/frame_log.dart';

import '../support/pump.dart';

void main() {
  testWidgets('Ctrl+Alt+R marks a recording on screen, and again to stop it', (tester) async {
    await pumpApp(tester);
    Future<void> chord() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }

    await chord();
    await tester.pump(const Duration(milliseconds: 100));
    expect(perfRecording.value, isTrue);
    expect(find.textContaining('● REC'), findsOneWidget);
    await chord();
    await tester.pump(const Duration(milliseconds: 100));
    expect(perfRecording.value, isFalse);
    expect(find.textContaining('STOPPED'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('STOPPED'), findsNothing, reason: 'gone once the flash is over');
    await disposeApp(tester);
  });
}
