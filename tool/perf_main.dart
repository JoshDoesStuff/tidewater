// Frame-timing probe. Runs the real app through the heavy scenarios and prints
// per-phase build/raster times, then exits.
//
//   flutter run -d windows --profile -t tool/perf_main.dart
//
// Always measure in --profile: debug builds are several times slower and say
// nothing about smoothness.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:window_manager/window_manager.dart';

class _Sample {
  _Sample(this.build, this.raster, this.total);
  final double build;
  final double raster;
  final double total;
}

final _phases = <String, List<_Sample>>{};
String _phase = 'startup';

double _ms(Duration d) => d.inMicroseconds / 1000;

String _stats(List<double> v) {
  if (v.isEmpty) return '-';
  final s = [...v]..sort();
  double p(double q) => s[((s.length - 1) * q).round()];
  return 'p50 ${p(.5).toStringAsFixed(1)}  p90 ${p(.9).toStringAsFixed(1)}  p99 ${p(.99).toStringAsFixed(1)}  max ${s.last.toStringAsFixed(1)}';
}

void _report() {
  debugPrint('\n===== frame timings (ms; 60 Hz budget is 16.7) =====');
  for (final e in _phases.entries) {
    final f = e.value;
    final slow = f.where((x) => x.total > 16.7).length;
    final bad = f.where((x) => x.total > 33.4).length;
    debugPrint('[${e.key}] frames=${f.length}  >16.7ms: $slow  >33.4ms: $bad');
    debugPrint('   build  ${_stats([for (final x in f) x.build])}');
    debugPrint('   raster ${_stats([for (final x in f) x.raster])}');
    debugPrint('   total  ${_stats([for (final x in f) x.total])}');
  }
  debugPrint('===== done =====');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(720, 520),
    center: true,
    title: 'Tidewater (perf)',
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);

  SchedulerBinding.instance.addTimingsCallback((List<ui.FrameTiming> timings) {
    for (final t in timings) {
      _phases.putIfAbsent(_phase, () => []).add(_Sample(_ms(t.buildDuration), _ms(t.rasterDuration), _ms(t.totalSpan)));
    }
  });

  runApp(UncontrolledProviderScope(container: container, child: const TidewaterApp()));
  unawaited(_scenario(container));
}

Future<void> _wait(double seconds) => Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));

Future<void> _scenario(ProviderContainer c) async {
  final router = c.read(routerProvider);
  final player = c.read(playbackProvider.notifier);

  await _wait(2); // let startup settle
  _phase = 'home idle';
  await _wait(3);

  _phase = 'tab changes (title reveal)';
  router.go('/library');
  await _wait(2.2);
  router.go('/home');
  await _wait(2.2);

  _phase = 'play album (recolor + wash)';
  await player.playIndex(6);
  await _wait(2.5);

  _phase = 'open Now Playing';
  c.read(nowPlayingOpenProvider.notifier).set(true);
  await _wait(2.5);

  _phase = 'Now Playing steady';
  await _wait(3);

  // Lyrics change every ~20 s of playback; seek just before a boundary so the
  // transition (slide, scale, blur, color) happens in the measured window.
  final engine = c.read(playbackEngineProvider);
  Future<void> lyricChanges() async {
    for (final s in [27, 47, 67, 87]) {
      await engine.seek(Duration(seconds: s, milliseconds: 400));
      await _wait(2.2);
    }
  }

  _phase = 'lyric line changes (card)';
  await lyricChanges();

  _phase = 'track skips (title swap + recolor)';
  for (var i = 0; i < 4; i++) {
    await player.next();
    await _wait(2.5);
  }

  _phase = 'Now Playing idle mode';
  await _wait(5);

  _phase = 'lyric line changes (idle list)';
  await engine.seek(const Duration(seconds: 1));
  await _wait(1);
  await lyricChanges();

  _report();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  exit(0);
}
