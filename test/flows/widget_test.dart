import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
import 'package:tidewater/core/color/cover_seed.dart';
import 'package:tidewater/ui/widgets/effects/glyph_run.dart';
import 'package:tidewater/ui/widgets/expressive_buttons.dart';
import 'package:tidewater/ui/widgets/effects/letter_reveal.dart';
import 'package:tidewater/ui/widgets/shapes/morph_path.dart';
import 'package:tidewater/ui/widgets/wavy_progress.dart';

import '../support/finders.dart';
import '../support/fake_library.dart';
import '../support/test_app.dart';

/// Pumps the app and returns its provider container. Always call [_dispose]
/// at the end of a test that plays audio so the simulated clock stops.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  FakeLibraryApi? api,
  bool signedIn = true,
}) async {
  final overrides = await testOverrides(api: api, signedIn: signedIn);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: const TidewaterApp(),
  ));
  await _advance(tester, const Duration(seconds: 2));
  return ProviderScope.containerOf(tester.element(find.byType(TidewaterApp)));
}

/// Queues album [index] and pauses, so Now Playing and the mini player have a
/// track without the simulated clock running.
Future<void> _startPaused(WidgetTester tester, ProviderContainer container, {int index = 0}) async {
  final player = container.read(playbackProvider.notifier);
  await player.playAlbum(fakeAlbums[index]);
  await player.toggle();
  await _advance(tester, const Duration(milliseconds: 600));
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
    expect(find.text('Jump back in'), findsOneWidget);
    expect(find.text('Shuffle all'), findsOneWidget);
    expect(byHint('Previous'), findsNothing, reason: 'no mini player until something plays');
    for (final d in Destination.values) {
      expect(find.text(d.label), findsWidgets);
    }
    await _dispose(tester);
  });

  testWidgets('filter chips hug their labels and sit in one row', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Library'));
    await _advance(tester, const Duration(seconds: 2));
    final albums = tester.getRect(find.widgetWithText(ExpressiveChip, 'Albums'));
    final songs = tester.getRect(find.widgetWithText(ExpressiveChip, 'Songs'));
    expect(albums.width, lessThan(200));
    expect(songs.width, lessThan(200));
    expect(songs.top, albums.top);
    expect(songs.left, greaterThan(albums.right));
    await _dispose(tester);
  });

  testWidgets('hero play button is gone quickly when the pointer moves to another card', (tester) async {
    await _pumpApp(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);

    // Opacity of each hero-row play button (icons in the carousel band).
    List<double> heroButtons() {
      final icons = find.byIcon(Icons.play_arrow_rounded);
      final values = <double>[];
      for (var i = 0; i < icons.evaluate().length; i++) {
        final y = tester.getCenter(icons.at(i)).dy;
        if (y < 284 || y > 484) continue; // the Jump back in carousel
        final fade = find.ancestor(of: icons.at(i), matching: find.byType(FadeTransition)).first;
        values.add(tester.widget<FadeTransition>(fade).opacity.value);
      }
      return values;
    }

    await mouse.moveTo(const Offset(260, 380)); // first hero
    await _advance(tester, const Duration(milliseconds: 1200));
    final settled = heroButtons();
    expect(settled.where((o) => o > .95).length, 1, reason: 'only the hovered hero shows its button');

    await mouse.moveTo(const Offset(930, 380)); // third hero
    await _advance(tester, const Duration(milliseconds: 200));
    // 200 ms in, the carousel is still expanding, but the old button must be gone.
    final moving = heroButtons();
    expect(moving.where((o) => o > .1).length, lessThanOrEqualTo(1), reason: 'old button still visible: $moving');
    await _advance(tester, const Duration(milliseconds: 1200));
    expect(heroButtons().where((o) => o > .95).length, 1);
    await mouse.removePointer();
    await _dispose(tester);
  });

  testWidgets('rail navigates to Library and back', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Library'));
    await _advance(tester, const Duration(seconds: 2));
    expect(find.text('12 albums'), findsOneWidget);
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
    await container.read(playbackProvider.notifier).playAlbum(fakeAlbums[6]);
    await _advance(tester, const Duration(milliseconds: 100));
    expect(container.read(playbackProvider).playing, isTrue);
    expect(container.read(activeAlbumIdProvider), 'a6');
    await _advance(tester, const Duration(seconds: 2));
    final after = Theme.of(tester.element(find.text('Jump back in'))).colorScheme.primary;
    expect(after, isNot(before));
    expect(after, AlbumScheme.of(CoverSeed.fromKey('a6'), Brightness.dark).primary);
    await container.read(playbackProvider.notifier).toggle();
    await _dispose(tester);
  });

  testWidgets('mini player opens Now Playing; Esc closes it', (tester) async {
    final container = await _pumpApp(tester);
    await _startPaused(tester, container);
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
    await _startPaused(tester, container);
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
    await _startPaused(tester, container);
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

  test('every cover scheme keeps accent text readable (WCAG >= 4.5), incl. gray art', () {
    double lum(Color c) {
      double ch(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
      return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
    }

    double ratio(Color a, Color b) {
      final l1 = lum(a);
      final l2 = lum(b);
      return (l1 > l2 ? l1 + .05 : l2 + .05) / (l1 > l2 ? l2 + .05 : l1 + .05);
    }

    // Placeholder hues from album ids, plus covers with no real color.
    final seeds = <(String, CoverSeed)>[
      for (final a in fakeAlbums) (a.title, CoverSeed.fromKey(a.id)),
      for (final (name, argb) in [("pure gray", 0xff808080), ("near black", 0xff101010), ("near white", 0xfff0f0f0), ("pale gray-blue", 0xffa0a4aa)])
        (name, CoverSeed(argb, muted: true)),
      for (final (name, argb) in [("red", 0xffff0000), ("yellow", 0xffffff00), ("green", 0xff00ff00), ("blue", 0xff0000ff), ("dark navy", 0xff0b1230)])
        (name, CoverSeed(argb)),
    ];
    for (final brightness in Brightness.values) {
      for (final (name, seed) in seeds) {
        final s = AlbumScheme.of(seed, brightness);
        final why = "$name $brightness";
        // Active lyric (primary) and body text on the lyrics card / surface.
        expect(ratio(s.primary, s.surfaceContainerHigh), greaterThanOrEqualTo(4.5), reason: why);
        expect(ratio(s.onSurface, s.surface), greaterThanOrEqualTo(4.5), reason: why);
        expect(ratio(s.onSurfaceVariant, s.surfaceContainerHigh), greaterThanOrEqualTo(4.5), reason: why);
      }
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
