import 'dart:async';
import 'dart:math' as math;

import '../models/track.dart';
import 'audio_backend.dart';
import 'play_queue.dart';
import 'playback_engine.dart';

/// The [PlaybackEngine] the app uses: owns the queue, shuffle and repeat, and
/// drives an [AudioBackend] with a two-item window (current + next) so tracks
/// join up gaplessly. Backend-agnostic, so it is fully unit-testable with a
/// simulated backend.
class QueueEngine implements PlaybackEngine {
  QueueEngine({required AudioBackend backend, math.Random? random})
      : _backend = backend,
        _queue = PlayQueue(random: random) {
    _subs
      ..add(backend.playing.listen(_onBackendPlaying))
      ..add(backend.position.listen(_onBackendPosition))
      ..add(backend.advanced.listen(_onAdvanced))
      ..add(backend.completed.listen((_) => _onCompleted()))
      ..add(backend.buffering.listen(_onBuffering))
      ..add(backend.errors.listen(_onError));
  }

  final AudioBackend _backend;
  final PlayQueue _queue;
  final _subs = <StreamSubscription<Object?>>[];

  final _states = StreamController<PlaybackState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _errors = StreamController<String>.broadcast();

  PlaybackState _state = const PlaybackState();
  LoopMode _repeat = LoopMode.off;
  double _volume = .7;
  bool _playing = false;
  bool _started = false;
  bool _buffering = false;
  bool _volumeSent = false;

  /// What the person asked for (play or pause), as opposed to [_playing],
  /// which follows what the backend reports. Used to recover from stalls.
  bool _intent = false;

  /// The backend holds a window for the current track.
  bool _opened = false;

  /// Where to start when the window is opened (a restored session, or a seek
  /// made before anything was playing).
  Duration _resumeAt = Duration.zero;

  Future<void> _tail = Future.value();

  /// Commands run one at a time, so a quick double skip cannot interleave.
  Future<void> _run(Future<void> Function() body) {
    final next = _tail.then((_) => body());
    _tail = next.catchError((Object _) {});
    return next;
  }

  @override
  PlaybackState get state => _state;

  /// The backend, for tests that need to poke it.
  AudioBackend get backendForTest => _backend;

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Duration get position => _opened ? _backend.currentPosition : _resumeAt;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<String> get errors => _errors.stream;

  void _emit() {
    _state = PlaybackState(
      queue: _queue.tracks,
      index: _queue.index,
      started: _started,
      playing: _playing,
      buffering: _buffering,
      volume: _volume,
      shuffle: _queue.shuffled,
      repeat: _repeat,
    );
    if (!_states.isClosed) _states.add(_state);
  }

  void _emitPosition(Duration p) {
    if (!_positions.isClosed) _positions.add(p);
  }

  // --- backend events ---------------------------------------------------------

  void _onBackendPlaying(bool playing) {
    if (!_opened || playing == _playing) return;
    _playing = playing;
    if (playing) _started = true;
    _emit();
  }

  void _onBackendPosition(Duration p) {
    if (_opened) _emitPosition(p);
  }

  void _onBuffering(bool value) {
    if (value == _buffering) return;
    _buffering = value;
    _emit();
  }

  /// The backend rolled over into the next item by itself.
  void _onAdvanced(int windowIndex) => _run(() async {
        if (!_opened || windowIndex < 1) return;
        _queue.advance(_repeat);
        _emit();
        _emitPosition(Duration.zero);
        await _backend.dropFirst();
        await _backend.setNext(_queue.peekNext(_repeat));
      });

  /// Everything queued has played (repeat is off).
  void _onCompleted() => _run(() async {
        if (!_opened) return;
        _playing = false;
        _intent = false;
        _opened = false;
        _resumeAt = Duration.zero;
        _queue.jumpTo(0);
        _emit();
        _emitPosition(Duration.zero);
      });

  /// The track (and when) we last restarted because it was not producing
  /// audio, so a second failure skips it instead of looping.
  String? _kickedId;
  DateTime _kickedAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _onError(String message) {
    if (!_errors.isClosed) _errors.add(message);
    // The backend may skip a broken file by itself (mpv does, and reports the
    // error just after moving on), so don't guess which track the error was
    // about: after a moment, check that the current one is really playing.
    Timer(const Duration(milliseconds: 400), () {
      _run(() async {
        final current = _queue.current;
        if (!_opened || !_intent || current == null) return;
        if (_playing && position > const Duration(milliseconds: 150)) return;
        final recent = DateTime.now().difference(_kickedAt) < const Duration(seconds: 10);
        if (_kickedId != current.id || !recent) {
          // First failure: try this track once more.
          _kickedId = current.id;
          _kickedAt = DateTime.now();
          await _open(play: true);
        } else if (_queue.index + 1 < _queue.tracks.length) {
          _kickedId = null;
          _queue.advance(LoopMode.off);
          await _open(play: true);
        } else {
          await _backend.pause();
          _playing = false;
          _intent = false;
          _emit();
        }
      });
    });
  }

  // --- helpers ----------------------------------------------------------------

  Future<void> _open({required bool play, Duration start = Duration.zero}) async {
    final cur = _queue.current;
    if (cur == null) return;
    final next = _queue.peekNext(_repeat);
    _opened = true;
    _resumeAt = Duration.zero;
    _playing = play;
    _intent = play;
    if (play) _started = true;
    _emit();
    _emitPosition(start);
    if (!_volumeSent) {
      _volumeSent = true;
      await _backend.setVolume(_volume);
    }
    await _backend.open([cur, ?next], start: start, play: play);
  }

  Future<void> _refreshNext() async {
    if (_opened) await _backend.setNext(_queue.peekNext(_repeat));
  }

  // --- commands ---------------------------------------------------------------

  @override
  Future<void> playQueue(List<Track> queue, {int index = 0, bool shuffle = false}) => _run(() async {
        if (queue.isEmpty) return;
        final wantShuffle = shuffle || _queue.shuffled;
        _queue.replace(queue, index: index);
        _queue.setShuffle(wantShuffle);
        await _open(play: true);
      });

  @override
  Future<void> restore(
    List<Track> queue, {
    int index = 0,
    Duration position = Duration.zero,
    bool shuffled = false,
    LoopMode repeat = LoopMode.off,
    double? volume,
  }) =>
      _run(() async {
        if (queue.isEmpty) return;
        _queue.replace(queue, index: index, alreadyShuffled: shuffled);
        _repeat = repeat;
        if (volume != null) {
          _volume = volume.clamp(0.0, 1.0);
          _volumeSent = false; // sent to the backend when playback first opens
        }
        _opened = false;
        _playing = false;
        _intent = false;
        _started = true;
        _resumeAt = position;
        _emit();
        _emitPosition(position);
      });

  @override
  Future<void> playIndex(int index) => _run(() async {
        if (!_queue.jumpTo(index)) return;
        await _open(play: true);
      });

  @override
  Future<void> play() => _run(() async {
        if (_queue.isEmpty) return;
        if (!_opened) {
          await _open(play: true, start: _resumeAt);
        } else if (!_playing || !_intent) {
          _playing = true;
          _intent = true;
          _started = true;
          _emit();
          await _backend.play();
        }
      });

  @override
  Future<void> pause() => _run(() async {
        if (!_playing && !_intent) return;
        _playing = false;
        _intent = false;
        _emit();
        if (_opened) await _backend.pause();
      });

  @override
  Future<void> stop() => _run(() async {
        if (_opened) await _backend.pause();
        _queue.clear();
        _opened = false;
        _playing = false;
        _intent = false;
        _started = false;
        _buffering = false;
        _resumeAt = Duration.zero;
        _emit();
        _emitPosition(Duration.zero);
      });

  @override
  Future<void> seek(Duration to) => _run(() async {
        final d = _queue.current?.duration ?? Duration.zero;
        var p = to < Duration.zero ? Duration.zero : to;
        if (d > Duration.zero && p > d) p = d;
        if (_opened) {
          await _backend.seek(p);
        } else {
          _resumeAt = p;
        }
        _emitPosition(p);
      });

  @override
  Future<void> next() => _run(() async {
        // Pressing next always moves on, even with repeat-one or at the end.
        if (!_queue.advance(LoopMode.all)) return;
        await _open(play: _playing);
      });

  @override
  Future<void> previous() => _run(() async {
        if (_queue.isEmpty) return;
        // Like most players: restart the track first, go back only near its start.
        if (position > const Duration(seconds: 3)) {
          if (_opened) {
            await _backend.seek(Duration.zero);
          } else {
            _resumeAt = Duration.zero;
          }
          _emitPosition(Duration.zero);
          return;
        }
        _queue.retreat();
        await _open(play: _playing);
      });

  @override
  Future<void> setVolume(double volume) => _run(() async {
        _volume = volume.clamp(0.0, 1.0);
        _emit();
        await _backend.setVolume(_volume);
      });

  @override
  Future<void> setShuffle(bool value) => _run(() async {
        _queue.setShuffle(value);
        _emit();
        await _refreshNext();
      });

  @override
  Future<void> setRepeat(LoopMode value) => _run(() async {
        _repeat = value;
        _emit();
        await _refreshNext();
      });

  @override
  Future<void> addNext(List<Track> tracks) => _run(() async {
        _queue.addNext(tracks);
        _emit();
        await _refreshNext();
      });

  @override
  Future<void> addLast(List<Track> tracks) => _run(() async {
        _queue.addLast(tracks);
        _emit();
        await _refreshNext();
      });

  @override
  Future<void> removeAt(int index) => _run(() async {
        final removingCurrent = index == _queue.index;
        _queue.removeAt(index);
        if (_queue.isEmpty) {
          if (_opened) await _backend.pause();
          _opened = false;
          _playing = false;
        _intent = false;
          _emit();
          return;
        }
        if (removingCurrent && _opened) {
          await _open(play: _playing);
        } else {
          _emit();
          await _refreshNext();
        }
      });

  @override
  Future<void> move(int from, int to) => _run(() async {
        _queue.move(from, to);
        _emit();
        await _refreshNext();
      });

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _backend.dispose();
    await _states.close();
    await _positions.close();
    await _errors.close();
  }
}
