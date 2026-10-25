import 'dart:async';
import 'dart:math' as math;

import '../models/track.dart';
import 'playback_engine.dart';

/// Plays nothing: advances a clock so the UI can be built and demoed before
/// a real engine (media_kit, milestone 3) exists.
class SimulatedEngine implements PlaybackEngine {
  SimulatedEngine({List<Track> queue = const [], this.tick = const Duration(milliseconds: 33), math.Random? random})
      : _state = PlaybackState(queue: queue),
        _random = random ?? math.Random();

  final Duration tick;
  final math.Random _random;

  PlaybackState _state;
  final _states = StreamController<PlaybackState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  Timer? _timer;
  final _clock = Stopwatch();
  Duration _base = Duration.zero;

  @override
  PlaybackState get state => _state;

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Duration get position {
    final p = _base + _clock.elapsed;
    final d = _state.track?.duration ?? Duration.zero;
    return p > d ? d : p;
  }

  @override
  Stream<Duration> get positions => _positions.stream;

  void _emit(PlaybackState s) {
    _state = s;
    _states.add(s);
  }

  void _startClock() {
    _base = position;
    _clock
      ..reset()
      ..start();
    _timer ??= Timer.periodic(tick, (_) => _onTick());
  }

  void _stopClock() {
    _base = position;
    _clock
      ..stop()
      ..reset();
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    if (position >= (_state.track?.duration ?? Duration.zero)) {
      _advance();
      return;
    }
    _positions.add(position);
  }

  void _advance() {
    if (_state.queue.isEmpty) return;
    if (_state.repeat) {
      _jump(_state.index);
    } else {
      _jump(_nextIndex());
    }
  }

  int _nextIndex() {
    final n = _state.queue.length;
    if (_state.shuffle && n > 1) {
      var i = _state.index;
      while (i == _state.index) {
        i = _random.nextInt(n);
      }
      return i;
    }
    return (_state.index + 1) % n;
  }

  void _jump(int index) {
    final wasPlaying = _state.playing;
    _base = Duration.zero;
    _clock.reset();
    if (wasPlaying) _clock.start();
    _emit(_state.copyWith(index: index, started: true));
    _positions.add(Duration.zero);
  }

  @override
  Future<void> playQueue(List<Track> queue, {int index = 0}) async {
    if (queue.isEmpty) return;
    _stopClock();
    _base = Duration.zero;
    _emit(_state.copyWith(queue: queue, index: index.clamp(0, queue.length - 1), started: true, playing: true));
    _startClock();
    _positions.add(Duration.zero);
  }

  @override
  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _state.queue.length) return;
    _stopClock();
    _base = Duration.zero;
    _emit(_state.copyWith(index: index, started: true, playing: true));
    _startClock();
    _positions.add(Duration.zero);
  }

  @override
  Future<void> play() async {
    if (_state.queue.isEmpty) return;
    if (_state.playing) return;
    _emit(_state.copyWith(playing: true, started: true));
    _startClock();
  }

  @override
  Future<void> pause() async {
    if (!_state.playing) return;
    _stopClock();
    _emit(_state.copyWith(playing: false));
  }

  @override
  Future<void> seek(Duration to) async {
    final d = _state.track?.duration ?? Duration.zero;
    _base = to < Duration.zero ? Duration.zero : (to > d ? d : to);
    _clock.reset();
    if (_state.playing) _clock.start();
    _positions.add(_base);
  }

  @override
  Future<void> next() async {
    if (_state.queue.isNotEmpty) _jump(_nextIndex());
  }

  @override
  Future<void> previous() async {
    if (_state.queue.isEmpty) return;
    // Like most players: restart the track first, go back only near its start.
    if (position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final n = _state.queue.length;
    _jump((_state.index - 1 + n) % n);
  }

  @override
  Future<void> setVolume(double volume) async => _emit(_state.copyWith(volume: volume.clamp(0.0, 1.0)));

  @override
  Future<void> setShuffle(bool value) async => _emit(_state.copyWith(shuffle: value));

  @override
  Future<void> setRepeat(bool value) async => _emit(_state.copyWith(repeat: value));

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _states.close();
    await _positions.close();
  }
}
