import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// In a profile build, says in the console which frames were slow and which thread was to
/// blame: "build" is Dart (widgets, layout, painting commands), "raster" is the GPU thread
/// (drawing them). Run with `flutter run -d windows --profile` and scroll.
void logSlowFrames() {
  if (!kProfileMode) return;
  var slow = 0;
  var total = 0;
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    for (final t in timings) {
      total++;
      final build = t.buildDuration.inMicroseconds / 1000;
      final raster = t.rasterDuration.inMicroseconds / 1000;
      if (build > 16 || raster > 16) {
        slow++;
        debugPrint('SLOW FRAME #$slow of $total: build ${build.toStringAsFixed(1)} ms, raster ${raster.toStringAsFixed(1)} ms '
            '(${build > raster ? 'Dart side' : 'GPU side'})');
      }
    }
  });
}
