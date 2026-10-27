import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// In a profile build, every three seconds that frames were drawn, says how they went:
///
/// `FRAMES 3s: 162 drawn, 41 over 16.7 ms | build avg 2.1 max 9.4 | raster avg 21.3 p90 30.2 max 41.0`
///
/// "build" is Dart (widgets, layout, painting commands), "raster" is the GPU thread. Run
/// with `flutter run -d windows --profile`, scroll, and flip the switches in `PerfFlags`
/// to see which one moves the raster numbers.
void logSlowFrames() {
  if (!kProfileMode) return;
  final build = <double>[];
  final raster = <double>[];
  var since = DateTime.now();
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      build.add(t.buildDuration.inMicroseconds / 1000);
      raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
    final now = DateTime.now();
    if (now.difference(since) < const Duration(seconds: 3)) return;
    since = now;
    if (raster.length >= 20) {
      double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
      final sorted = [...raster]..sort();
      final slow = [for (var i = 0; i < raster.length; i++) if (raster[i] > 16.7 || build[i] > 16.7) 1].length;
      String f(double v) => v.toStringAsFixed(1);
      debugPrint('FRAMES 3s: ${raster.length} drawn, $slow over 16.7 ms | build avg ${f(avg(build))} max ${f(build.reduce((a, b) => a > b ? a : b))}'
          ' | raster avg ${f(avg(raster))} p90 ${f(sorted[(sorted.length * .9).floor()])} max ${f(sorted.last)}');
    }
    build.clear();
    raster.clear();
  });
}
