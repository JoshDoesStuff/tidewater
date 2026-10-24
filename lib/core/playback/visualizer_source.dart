import 'dart:math' as math;

/// Source of spectrum levels for the visualizers.
///
/// libmpv (via media_kit) does not expose audio samples, so this is a
/// SIMULATION: levels are synthesized from time, not from the music. A real
/// FFT source (parallel FFmpeg decode / flutter_soloud / native tap) is a
/// later milestone and will implement the same interface.
abstract class VisualizerSource {
  static const bands = 64;

  /// Smoothed levels in 0..1, [bands] long.
  List<double> get levels;

  /// Monotonic phase in the demo's "tt" units (about 2.7 per second).
  double get phase;

  /// Advance the model to now. Cheap and safe to call from several painters
  /// per frame; the second call in a frame sees a tiny dt.
  void update({required bool playing});

  double average(int from, int to);
}

/// 64 bands, fast attack, slow decay, calm when paused (see the demo).
class SimulatedVisualizerSource extends VisualizerSource {
  final List<double> _levels = List.filled(VisualizerSource.bands, .04);
  final Stopwatch _clock = Stopwatch()..start();
  Duration _last = Duration.zero;
  double _phase = 0;

  @override
  List<double> get levels => _levels;

  @override
  double get phase => _phase;

  @override
  void update({required bool playing}) {
    final now = _clock.elapsed;
    final dt = math.min(.1, (now - _last).inMicroseconds / 1e6);
    _last = now;
    if (dt <= 0) return;
    _phase += .045 * 60 * dt;
    final rate = playing ? .22 : .08;
    // The demo smooths per 60 Hz frame; convert to a frame-rate independent factor.
    final k = 1 - math.pow(1 - rate, dt * 60).toDouble();
    final tt = _phase;
    for (var i = 0; i < _levels.length; i++) {
      final target = playing
          ? (.3 + .7 * (math.sin(tt * 1.3 + i * .37) * math.cos(tt * .7 + i * .11)).abs()) *
              (.55 + .45 * math.sin(i * 1.7 + tt * 2.2).abs())
          : .03;
      _levels[i] += (target - _levels[i]) * k;
    }
  }

  @override
  double average(int from, int to) {
    var s = 0.0;
    for (var i = from; i < to; i++) {
      s += _levels[i];
    }
    return s / (to - from);
  }
}
