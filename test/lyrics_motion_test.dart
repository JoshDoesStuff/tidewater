import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/core/lyrics/placeholder_lyrics.dart';
import 'package:tidewater/ui/now_playing/lyrics_list.dart';
import 'package:tidewater/ui/now_playing/lyrics_motion.dart';

void main() {
  group('line classes (demo CSS d0 / d1 / d2 / rest)', () {
    test('card: .ll', () {
      final d0 = lineTarget(0, LyricsStyle.card);
      expect((d0.opacity, d0.blur, d0.scale, d0.accent), (1.0, 0.0, 1.3, 1.0));
      final d1 = lineTarget(1, LyricsStyle.card);
      expect((d1.opacity, d1.blur, d1.scale, d1.accent), (.45, .8, 1.0, 0.0));
      final d2 = lineTarget(2, LyricsStyle.card);
      expect((d2.opacity, d2.blur, d2.scale, d2.accent), (.25, 1.5, .92, 0.0));
      final rest = lineTarget(5, LyricsStyle.card);
      expect((rest.opacity, rest.blur, rest.scale, rest.accent), (.2, 2.0, .92, 0.0));
    });

    test('idle: .il', () {
      final d0 = lineTarget(0, LyricsStyle.idle);
      expect((d0.opacity, d0.blur, d0.scale, d0.accent), (1.0, 0.0, 1.28, 1.0));
      final d1 = lineTarget(1, LyricsStyle.idle);
      expect((d1.opacity, d1.blur, d1.scale, d1.accent), (.5, 1.0, .95, 0.0));
      final d2 = lineTarget(2, LyricsStyle.idle);
      expect((d2.opacity, d2.blur, d2.scale, d2.accent), (.28, 2.0, .86, 0.0));
      final rest = lineTarget(9, LyricsStyle.idle);
      expect((rest.opacity, rest.blur, rest.scale, rest.accent), (.2, 3.0, .86, 0.0));
    });
  });

  test('list anchors match the demo (card 52 / .5, idle 220 / .64)', () {
    // JS: translateY(52 - (offsetTop + offsetHeight * .5))
    expect(listOffsetFor(lineTop: 100, lineHeight: 30, style: LyricsStyle.card), 52 - (100 + 30 * .5));
    // JS: translateY(220 - (offsetTop + offsetHeight * .64))
    expect(listOffsetFor(lineTop: 300, lineHeight: 90, style: LyricsStyle.idle), 220 - (300 + 90 * .64));
  });

  test('transition durations match the demo (.8s .8s .9s .6s .9s)', () {
    expect(LyricTiming.opacity.inMilliseconds, 800);
    expect(LyricTiming.blur.inMilliseconds, 800);
    expect(LyricTiming.scale.inMilliseconds, 900);
    expect(LyricTiming.color.inMilliseconds, 600);
    expect(LyricTiming.slide.inMilliseconds, 900);
  });

  group('CssTransition', () {
    const ms = Duration(milliseconds: 1);
    test('runs from the old to the new value over the full duration', () {
      final t = CssTransition(0)..retarget(10, Duration.zero, ms * 800, Curves.linear);
      expect(t.at(Duration.zero), 0);
      expect(t.at(ms * 400), closeTo(5, 1e-9));
      expect(t.at(ms * 800), 10);
      expect(t.at(ms * 5000), 10);
      expect(t.isActive(ms * 799), isTrue);
      expect(t.isActive(ms * 800), isFalse);
    });

    test('retargeting mid-flight continues from the value being shown (no jump)', () {
      final t = CssTransition(0)..retarget(10, Duration.zero, ms * 1000, Curves.linear);
      final shown = t.at(ms * 300); // 3.0
      t.retarget(0, ms * 300, ms * 1000, Curves.linear);
      expect(t.at(ms * 300), closeTo(shown, 1e-9));
      expect(t.at(ms * 300 + ms * 1000), 0);
    });

    test('retargeting to the current target does not restart it', () {
      final t = CssTransition(0)..retarget(10, Duration.zero, ms * 1000, Curves.linear);
      final before = t.at(ms * 600);
      t.retarget(10, ms * 600, ms * 1000, Curves.linear);
      expect(t.at(ms * 600), before);
      expect(t.at(ms * 1000), 10);
    });

    test('zero duration (reduced motion) is instant', () {
      final t = CssTransition(0)..retarget(7, Duration.zero, Duration.zero, Curves.linear);
      expect(t.at(Duration.zero), 7);
      expect(t.isActive(Duration.zero), isFalse);
    });
  });

  testWidgets('the list follows playback position and keeps one stable semantics node', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Center(child: SizedBox(width: 580, height: 128, child: LyricsList(style: LyricsStyle.card))),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('Lyrics'), findsOneWidget);
    String active() => tester.getSemantics(find.bySemanticsLabel('Lyrics')).value;

    expect(active(), placeholderLyrics.lines[0].text);
    container.read(positionProvider).value = const Duration(seconds: 30); // past line 2 start (28 s)
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // 2 s: every transition finishes
    }
    expect(active(), placeholderLyrics.lines[1].text);
    container.read(positionProvider).value = const Duration(seconds: 100);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(active(), placeholderLyrics.lines[4].text); // 88 s line
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
