// The cover pipeline run (B cold, C warm) without hands: Albums sat on, flung down and back,
// Songs tab, letter jumps A > M > Z, the whole Songs list flung down and back to the top.
// Run against the saved server in a profile build; read the result in %TEMP%\tidewater_perf.log:
//   flutter drive --profile -d windows --driver=test_driver/integration_test.dart --target=integration_test/cover_run_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tidewater/app/frame_log.dart';
import 'package:tidewater/main.dart' as app;
import 'package:tidewater/ui/widgets/smooth_scroll.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('cover run', (tester) async {
    final semantics = tester.ensureSemantics();

    Future<void> wait(double seconds) async {
      await Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));
      await tester.pump();
    }

    Future<void> step(String name) async {
      perfNote('RUN $name');
      await wait(0.2);
    }

    Future<void> tap(String label) async {
      await tester.tap(find.bySemanticsLabel(label).first, warnIfMissed: false);
      await wait(0.3);
    }

    // A trackpad fling of the page's list at the app's top speed (6,000 px/s), [times] in a row:
    // the same ballistic scroll a release starts. (Synthetic drags did not move the list.)
    Future<void> fling(double velocity, int times) async {
      for (var i = 0; i < times; i++) {
        final lists = [
          for (final s in tester.stateList<ScrollableState>(find.byType(Scrollable)))
            if (s.position is ScrollPositionWithSingleContext && s.position.axis == Axis.vertical) s.position,
        ]..sort((a, b) => b.maxScrollExtent.compareTo(a.maxScrollExtent));
        if (lists.isEmpty) return;
        final list = lists.first as ScrollPositionWithSingleContext;
        // Down to the bottom (or back to the top): stop at the edge.
        if (velocity > 0 ? list.pixels >= list.maxScrollExtent : list.pixels <= list.minScrollExtent) return;
        list.goBallistic(velocity);
        await wait(0.7);
      }
    }

    await app.main();
    // Maximized, so the run sees as many cards per screen as the monitor it runs on.
    await windowManager.maximize();
    await wait(1);
    final view = tester.view;
    perfNote('RUN window ${view.physicalSize.width.round()}x${view.physicalSize.height.round()} '
        'scale ${view.devicePixelRatio}');
    // Cold: let the first-launch cover save finish before the steps, as in the hand runs
    // (--dart-define=START_WAIT=45).
    await wait(const int.fromEnvironment('START_WAIT', defaultValue: 8).toDouble());
    await step('start');

    await tap('Library');
    await tap('Albums');
    await step('albums hands off');
    await wait(10);

    await step('albums fling');
    await fling(DeferringScrollPhysics.maxSpeed, 8);
    await fling(-DeferringScrollPhysics.maxSpeed, 8);
    await wait(3);

    await tap('Songs');
    await step('songs hands off');
    await wait(6);

    await step('letters');
    for (final l in ['A', 'M', 'Z']) {
      await tap('Jump to $l');
      await wait(3);
    }
    await tap('Jump to A');
    await wait(3);

    await step('songs fling');
    await fling(DeferringScrollPhysics.maxSpeed, 1000);
    await wait(3);
    await fling(-DeferringScrollPhysics.maxSpeed, 1000);
    await wait(5);

    final images = PaintingBinding.instance.imageCache;
    // Decodes, downloads and disk reads: the sum of the FRAMES lines (the log counts them per window).
    await step('end imageCache=${images.currentSize} '
        '(${(images.currentSizeBytes / 1048576).round()} MB of ${(images.maximumSizeBytes / 1048576).round()})');
    semantics.dispose();
  }, timeout: const Timeout(Duration(minutes: 15)));
}
