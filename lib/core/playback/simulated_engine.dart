import 'dart:async';

import '../models/track.dart';
import 'audio_backend.dart';
import 'queue_engine.dart';

/// Plays nothing: a clock that advances through the window like a real
/// backend would. Used by the tests, previews and the performance tools, so
/// they exercise the real queue logic without sound.
class SimulatedBackend implements AudioBackend {
  SimulatedBackend({this.tick = const Duration(milliseconds: 33)});

  final Duration tick;

  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _advanced = StreamController<int>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _errors = StreamController<String>.broadcast();

  List<Track> _window = [];
  int _at = 0;
  Timer? _timer;
  final _clock = Stopwatch();
  Duration _base = Duration.zero;
  bool _isPlaying = false;

  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<int> get advanced => _advanced.stream;
  @override
  Stream<void> get completed => _completed.stream;
  @override
  Stream<bool> get buffering => _buffering.stream;
  @override
  Stream<String> get errors => _errors.stream;

  /// For tests: pretend the current track failed to play.
  void emitError(String message) {
    // A track that fails to load goes nowhere: the clock stops.
    _stopClock();
    _base = Duration.zero;
    _errors.add(message);
  }

  Duration get _duration => _window.isEmpty ? Duration.zero : _window[_at].duration;

  @override
  Duration get currentPosition {
    final p = _base + _clock.elapsed;
    return p > _duration ? _duration : p;
  }

  void _startClock() {
    _base = currentPosition;
    _clock
      ..reset()
      ..start();
    _timer ??= Timer.periodic(tick, (_) => _onTick());
  }

  void _stopClock() {
    _base = currentPosition;
    _clock
      ..stop()
      ..reset();
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    if (currentPosition >= _duration) {
      if (_at + 1 < _window.length) {
        _at++;
        _base = Duration.zero;
        _clock
          ..reset()
          ..start();
        _advanced.add(_at);
      } else {
        _stopClock();
        _isPlaying = false;
        _completed.add(null);
      }
      return;
    }
    _position.add(currentPosition);
  }

  @override
  Future<void> open(List<Track> window, {Duration start = Duration.zero, bool play = true}) async {
    _stopClock();
    _window = [...window];
    _at = 0;
    _base = start;
    _isPlaying = play;
    if (play) _startClock();
  }

  @override
  Future<void> setNext(Track? track) async {
    if (_window.length > _at + 1) _window.removeRange(_at + 1, _window.length);
    if (track != null) _window.add(track);
  }

  @override
  Future<void> dropFirst() async {
    if (_at > 0) {
      _window.removeAt(0);
      _at = 0;
    }
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _startClock();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _stopClock();
  }

  @override
  Future<void> seek(Duration position) async {
    final p = position > _duration ? _duration : position;
    _base = p;
    _clock.reset();
    if (_isPlaying) _clock.start();
    _position.add(p);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    for (final c in [_playing, _position, _advanced, _completed, _buffering, _errors]) {
      await c.close();
    }
  }
}

/// A [QueueEngine] on the simulated backend.
class SimulatedEngine extends QueueEngine {
  SimulatedEngine({List<Track> queue = const [], Duration tick = const Duration(milliseconds: 33), super.random})
      : super(backend: SimulatedBackend(tick: tick)) {
    if (queue.isNotEmpty) restore(queue);
  }
}
