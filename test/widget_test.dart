import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/destinations.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/app/theme/album_scheme.dart';
import 'package:tidewater/app/theme/motion.dart';
import 'package:tidewater/core/data/fake_library.dart';
import 'package:tidewater/ui/widgets/effects/glyph_run.dart';
import 'package:tidewater/ui/widgets/effects/letter_reveal.dart';
import 'package:tidewater/ui/widgets/shapes/morph_path.dart';
import 'package:tidewater/ui/widgets/wavy_progress.dart';

/// Pumps the app and returns its provider container. Always call [_dispose]
/// at the end of a test that plays audio so the simulated clock stops.
Future<ProviderContainer> _pumpApp(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const TidewaterApp(),
  ));
  await _advance(tester, const Duration(seconds: 2));
  return ProviderScope.containerOf(tester.element(find.byType(TidewaterApp)));
}

/// Advances fake time in 100 ms frames so route and implicit animations run.
Future<void> _advance(WidgetTester tester, Duration total) async {
  var left = total;
  while (left > Duration.zero) {
    final step = left > const Duration(milliseconds: 100) ? const Duration(milliseconds: 100) : left;
    await tester.pump(step);
    left -= step;
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _advance(tester, const Duration(seconds: 1));
}

void main() {
  testWidgets('shell shows rail, mini player, FAB and Home', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Good evening'), findsNothing); // letters are separate widgets
    expect(find.text('Jump back in'), findsOneWidget);
    expect(find.text('Shuffle all'), findsOneWidget);
    expect(find.text(fakeTracks.first.title), findsWidgets); // mini player
    for (final d in Destination.values) {
      expect(find.text(d.label), findsWidgets);
    }
    await _dispose(tester);
  });

  testWidgets('filter chips hug their labels and sit in one row', (tester) async {
    await _pumpApp(tester);
    final all = tester.getRect(find.ancestor(of: find.text('All'), matching: find.byType(AnimatedContainer)).first);
    final albums = tester.getRect(find.ancestor(of: find.text('Albums'), matching: find.byType(AnimatedContainer)).first);
    expect(all.width, lessThan(200));
    expect(albums.width, lessThan(200));
    expect(albums.top, all.top);
    expect(albums.left, greaterThan(all.right));
    await _dispose(tester);
  });

  testWidgets('rail navigates to Library and back', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Library'));
    await _advance(tester, const Duration(seconds: 2));
    expect(find.text('1,284 albums · 96 GB'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await _advance(tester, const Duration(seconds: 2));
    expect(find.text('Jump back in'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('page titles bounce in again on every tab change', (tester) async {
    await _pumpApp(tester);
    // Letters are textures; read each one's opacity from the render object.
    // `.last`: while the route transition runs, the outgoing page's title is
    // still in the tree underneath the incoming one.
    List<double> letters() => tester.renderObject<RenderGlyphRun>(find.byType(GlyphRunLeaf).last).debugOpacities();

    expect(letters().every((o) => o == 1), isTrue); // settled after the first load
    await tester.tap(find.text('Library'));
    await _advance(tester, const Duration(seconds: 2));
    await tester.tap(find.text('Home'));
    await _advance(tester, const Duration(milliseconds: 600));
    // Mid-reveal: the first letters are in, the last have not arrived yet.
    final mid = letters();
    expect(mid.first, greaterThan(.5));
    expect(mid.last, lessThan(1));
    await _advance(tester, const Duration(seconds: 3));
    expect(letters().every((o) => o == 1), isTrue);
    await _dispose(tester);
  });

  testWidgets('LetterSwap pops the old text out before the new text pops in', (tester) async {
    final text = ValueNotifier('ab');
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<String>(
        valueListenable: text,
        builder: (context, t, _) => Center(child: LetterSwap(text: t, style: const TextStyle(fontSize: 20))),
      ),
    ));
    final semantics = tester.ensureSemantics();
    List<double> letters() => tester.renderObject<RenderGlyphRun>(find.byType(GlyphRunLeaf)).debugOpacities();

    await _advance(tester, const Duration(seconds: 2));
    expect(find.bySemanticsLabel('ab'), findsOneWidget);
    expect(letters(), [1, 1]);

    text.value = 'xy';
    await _advance(tester, const Duration(milliseconds: 250));
    // Still the old text, now on its way out (first letter fading).
    expect(find.bySemanticsLabel('ab'), findsOneWidget);
    expect(find.bySemanticsLabel('xy'), findsNothing);
    expect(letters().first, lessThan(1));

    await _advance(tester, const Duration(milliseconds: 350));
    // Swapped: the new text is entering, the old is gone.
    expect(find.bySemanticsLabel('ab'), findsNothing);
    expect(find.bySemanticsLabel('xy'), findsOneWidget);
    await _advance(tester, const Duration(seconds: 2));
    expect(letters(), [1, 1]);
    semantics.dispose();
  });

  testWidgets('animated letters are hidden from semantics behind one stable label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: LetterReveal(text: 'Library', style: TextStyle(fontSize: 30))),
    ));
    await _advance(tester, const Duration(milliseconds: 300)); // mid-animation
    expect(find.bySemanticsLabel('Library'), findsOneWidget);
    expect(find.bySemanticsLabel('L'), findsNothing);
    await _advance(tester, const Duration(seconds: 2));
    expect(find.bySemanticsLabel('Library'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('narrow window collapses rail labels and FAB', (tester) async {
    await _pumpApp(tester, size: const Size(800, 600));
    expect(find.text('Shuffle all'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('reduced-motion setting reaches MediaQuery', (tester) async {
    final container = await _pumpApp(tester);
    expect(Motion.reduced(tester.element(find.text('Jump back in'))), isFalse);
    container.read(reduceMotionProvider.notifier).set(true);
    await _advance(tester, const Duration(seconds: 1));
    expect(Motion.reduced(tester.element(find.text('Jump back in'))), isTrue);
    await _dispose(tester);
  });

  testWidgets('playing an album recolors the theme and starts playback', (tester) async {
    final container = await _pumpApp(tester);
    final before = Theme.of(tester.element(find.text('Jump back in'))).colorScheme.primary;
    await container.read(playbackProvider.notifier).playIndex(6);
    await _advance(tester, const Duration(milliseconds: 100));
    expect(container.read(playbackProvider).playing, isTrue);
    expect(container.read(activeAlbumIndexProvider), 6);
    await _advance(tester, const Duration(seconds: 2));
    final after = Theme.of(tester.element(find.text('Jump back in'))).colorScheme.primary;
    expect(after, isNot(before));
    expect(after, AlbumScheme.of(fakeAlbums[6], Brightness.dark).primary);
    await container.read(playbackProvider.notifier).toggle();
    await _dispose(tester);
  });

  testWidgets('mini player opens Now Playing; Esc closes it', (tester) async {
    final container = await _pumpApp(tester);
    await tester.tap(find.byTooltip('Previous').first, warnIfMissed: false);
    container.read(nowPlayingOpenProvider.notifier).set(true);
    await _advance(tester, const Duration(seconds: 2));
    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('LYRICS'), findsOneWidget);
    expect(find.text('Synced lyrics'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _advance(tester, const Duration(seconds: 1));
    expect(container.read(nowPlayingOpenProvider), isFalse);
    expect(find.text('Now playing'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('L toggles lyrics, V cycles visualizer style in Now Playing', (tester) async {
    final container = await _pumpApp(tester);
    container.read(nowPlayingOpenProvider.notifier).set(true);
    await _advance(tester, const Duration(seconds: 2));
    expect(container.read(lyricsOnProvider), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await _advance(tester, const Duration(seconds: 1));
    expect(container.read(lyricsOnProvider), isFalse);
    final before = container.read(vizModeProvider);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await _advance(tester, const Duration(milliseconds: 100));
    expect(container.read(vizModeProvider), before.next);
    container.read(nowPlayingOpenProvider.notifier).set(false);
    await _advance(tester, const Duration(seconds: 1));
    await _dispose(tester);
  });

  testWidgets('goes idle after 3.5 s while playing, never while paused', (tester) async {
    final container = await _pumpApp(tester);
    container.read(nowPlayingOpenProvider.notifier).set(true);
    await _advance(tester, const Duration(seconds: 2));
    await _advance(tester, const Duration(seconds: 5));
    expect(container.read(idleProvider), isFalse, reason: 'paused');
    await container.read(playbackProvider.notifier).toggle();
    await _advance(tester, const Duration(seconds: 5));
    expect(container.read(idleProvider), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await _advance(tester, const Duration(milliseconds: 300));
    expect(container.read(idleProvider), isFalse);
    await container.read(playbackProvider.notifier).toggle();
    container.read(nowPlayingOpenProvider.notifier).set(false);
    await _advance(tester, const Duration(seconds: 1));
    await _dispose(tester);
  });

  test('every album scheme keeps accent text readable (WCAG >= 4.5)', () {
    double lum(Color c) {
      double ch(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
      return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
    }

    double ratio(Color a, Color b) {
      final l1 = lum(a);
      final l2 = lum(b);
      return (l1 > l2 ? l1 + .05 : l2 + .05) / (l1 > l2 ? l2 + .05 : l1 + .05);
    }

    for (final album in fakeAlbums) {
      final s = AlbumScheme.of(album, Brightness.dark);
      // Active lyric (primary) and body text on the lyrics card / surface.
      expect(ratio(s.primary, s.surfaceContainerHigh), greaterThanOrEqualTo(4.5), reason: album.title);
      expect(ratio(s.onSurface, s.surface), greaterThanOrEqualTo(4.5), reason: album.title);
      expect(ratio(s.onSurfaceVariant, s.surfaceContainerHigh), greaterThanOrEqualTo(4.5), reason: album.title);
    }
  });

  test('morph path stays inside its box at both ends', () {
    const size = Size(100, 100);
    final squircle = morphPath(size, m: 0, params: ShapeKind.cookie.params).getBounds();
    expect(squircle.left, closeTo(0, 1));
    expect(squircle.right, closeTo(100, 1));
    final lobed = morphPath(size, m: 1, params: ShapeKind.clover.params).getBounds();
    expect(lobed.width, lessThanOrEqualTo(100 * ShapeKind.clover.params.base * (1 + ShapeKind.clover.params.amp) + 1));
    });

  test('no morph shape pokes outside its box (flat-clipped lobes)', () {
    const size = Size(440, 440);
    const halo = ShapeParams(lobes: 12, amp: .05, base: .97);
    const ambient = ShapeParams(lobes: 7, amp: .09, base: .95);
    final all = [for (final k in ShapeKind.values) k.params, halo, ambient];
    for (final params in all) {
      for (final m in [0.0, .5, 1.0]) {
        for (final rot in [0.0, .3, 1.1, 2.9]) {
          for (final squareBase in [true, false]) {
            final b = morphPath(size, m: m, params: params, rot: rot, squareBase: squareBase).getBounds();
            final why = '$params m=$m rot=$rot squareBase=$squareBase $b';
            expect(b.left, greaterThanOrEqualTo(-.01), reason: why);
            expect(b.top, greaterThanOrEqualTo(-.01), reason: why);
            expect(b.right, lessThanOrEqualTo(440.01), reason: why);
            expect(b.bottom, lessThanOrEqualTo(440.01), reason: why);
          }
        }
      }
    }
  });

  testWidgets('track title swap speed setting scales the animation and persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    expect(container.read(letterSpeedProvider), 1);
    container.read(letterSpeedProvider.notifier).set(2.5);
    expect(prefs.getDouble('letter_speed'), 2.5);
    container.read(letterSpeedProvider.notifier).set(99);
    expect(container.read(letterSpeedProvider), LetterSpeedNotifier.max);

    final semantics = tester.ensureSemantics();
    // (old title gone, new title showing) 300 ms after the text changes.
    Future<(bool, bool)> run(double speed) async {
      final text = ValueNotifier('ab');
      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<String>(
          valueListenable: text,
          builder: (context, t, _) => Center(child: LetterSwap(text: t, speed: speed, style: const TextStyle(fontSize: 20))),
        ),
      ));
      await _advance(tester, const Duration(seconds: 3));
      text.value = 'xy';
      await _advance(tester, const Duration(milliseconds: 300));
      final result = (
        find.bySemanticsLabel('ab').evaluate().isEmpty,
        find.bySemanticsLabel('xy').evaluate().isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      return result;
    }

    final slow = await run(.5);
    final fast = await run(3);
    semantics.dispose();
    expect(slow, (false, false), reason: 'at 0.5x the old title is still leaving after 300 ms');
    expect(fast, (true, true), reason: 'at 3x the swap has already happened after 300 ms');
  });

  test('squiggle grows continuously with the playhead (no sampling-step jumps)', () {
    double? previousRight;
    for (var i = 0; i <= 200; i++) {
      final end = 100 + i * .05; // 10 px in 0.05 px increments
      final b = wavePath(start: 2, end: end, centerY: 20, amplitude: 4, wavelength: 28, phase: 1.3).getBounds();
      expect(b.right, closeTo(end, .001), reason: 'end=$end');
      if (previousRight != null) {
        expect(b.right - previousRight, lessThanOrEqualTo(.05 + 1e-4), reason: 'jumped at end=$end');
      }
      previousRight = b.right;
    }
  });

  test('squiggle is finely sampled: no point farther than 2 px from the next', () {
    final metric = wavePath(start: 0, end: 300, centerY: 0, amplitude: 4, wavelength: 18, phase: 0).computeMetrics().first;
    // Arc length of a sine with amplitude 4 / wavelength 18 over 300 px, with a
    // generous allowance: a coarse polyline would measure noticeably shorter.
    final ideal = _sineArcLength(300, 4, 18);
    expect(metric.length, closeTo(ideal, ideal * .005));
  });

  test('motion tokens match the spec', () {
    expect(Motion.fast.inMilliseconds, 150);
    expect(Motion.medium.inMilliseconds, 300);
    expect(Motion.slow.inMilliseconds, 520);
    expect(Motion.recolor.inMilliseconds, 800);
  });

  test('destinations resolve from locations', () {
    expect(Destination.fromLocation('/library'), Destination.library);
    expect(Destination.fromLocation('/library/album/1'), Destination.library);
    expect(Destination.fromLocation('/nope'), isNull);
  });
}

/// Numerically integrated arc length of y = a*sin(2*pi*x/wl) over [0, length].
double _sineArcLength(double length, double a, double wl) {
  var sum = 0.0;
  const n = 200000;
  final dx = length / n;
  for (var i = 0; i < n; i++) {
    final x = (i + .5) * dx;
    final slope = a * 2 * math.pi / wl * math.cos(2 * math.pi * x / wl);
    sum += math.sqrt(1 + slope * slope) * dx;
  }
  return sum;
}
