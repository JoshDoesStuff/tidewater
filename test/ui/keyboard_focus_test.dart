import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

/// The tooltip of whatever button holds keyboard focus, or null.
String? _focusedTooltip() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Tooltip>()?.message;

void main() {
  testWidgets('Space with a button focused plays or pauses once and does not press the button', (tester) async {
    final c = await pumpApp(tester);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]); // three tracks
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(playbackProvider).playing, isTrue);

    // Tab until the mini player's Next button has focus.
    for (var i = 0; i < 80 && _focusedTooltip() != 'Next'; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(_focusedTooltip(), 'Next', reason: 'Next should be reachable with Tab');
    expect(
      find.descendant(of: find.byTooltip('Next'), matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null)),
      findsOneWidget,
      reason: 'a focus ring is drawn around the focused button',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).index, 0, reason: 'Space must not also press Next');
    expect(c.read(playbackProvider).playing, isFalse, reason: 'Space paused');
    await disposeApp(tester);
  });
}
