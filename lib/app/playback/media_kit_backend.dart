import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:media_kit/media_kit.dart' as mk;

import '../../core/models/track.dart';
import '../../core/playback/audio_backend.dart';

/// [AudioBackend] on libmpv via media_kit. The only file that touches
/// media_kit; nothing else in the app sees its types.
///
/// mpv gets a two-item playlist (current + next) so the second track is
/// already prefetched when the first ends (gapless). Changes the engine asks
/// for (open, setNext, dropFirst) never raise `advanced`; only mpv rolling
/// over by itself does.
class MediaKitBackend implements AudioBackend {
  MediaKitBackend({required this.resolve, mk.Player? player})
      : _player = player ??
            mk.Player(
              configuration: const mk.PlayerConfiguration(title: 'Tidewater', logLevel: mk.MPVLogLevel.warn),
            ) {
    _configure();
    _subs
      ..add(_player.stream.playing.listen(_playing.add))
      ..add(_player.stream.position.listen((p) => _position.add(_clamp(p))))
      ..add(_player.stream.buffering.listen(_buffering.add))
      ..add(_player.stream.playlist.listen(_onPlaylist))
      ..add(_player.stream.completed.listen((done) {
        // mpv reports end-of-file for every file; the window is only finished
        // when there is nothing after the item that just ended.
        if (done && !_opening && _at >= _ids.length - 1) _completed.add(null);
      }))
      ..add(_player.stream.error.listen((e) {
        if (e.isEmpty) return;
        debugPrint('[mpv error] $e');
        _errors.add('Couldn\'t play this track.');
      }));
  }

  /// Stream URL for a track id (auth included).
  final Uri Function(String trackId) resolve;
  final mk.Player _player;
  final _subs = <StreamSubscription<Object?>>[];

  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _advanced = StreamController<int>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _errors = StreamController<String>.broadcast();

  /// Mirror of the mpv playlist (ids), so edits can be skipped when nothing
  /// changed and so we know which item mpv is on.
  List<String> _ids = [];
  int _at = 0;
  bool _opening = false;

  Future<void> _configure() async {
    final platform = _player.platform;
    if (platform is mk.NativePlayer) {
      // Join consecutive tracks without a gap even when formats differ.
      await platform.setProperty('gapless-audio', 'yes');
      await platform.setProperty('prefetch-playlist', 'yes');
      await platform.setProperty('audio-client-name', 'Tidewater');
      // Nothing written to disk by the player: its stream cache stays in memory, and
      // it does not save a resume position per file or keep a log.
      await platform.setProperty('cache-on-disk', 'no');
      await platform.setProperty('save-position-on-quit', 'no');
    }
  }

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

  @override
  Duration get currentPosition => _clamp(_player.state.position);

  /// mpv briefly reports a negative position while two tracks are joined.
  static Duration _clamp(Duration p) => p < Duration.zero ? Duration.zero : p;

  mk.Media _media(Track t, {Duration start = Duration.zero}) => mk.Media(
        resolve(t.id).toString(),
        extras: {'id': t.id},
        start: start > Duration.zero ? start : null,
      );

  void _onPlaylist(mk.Playlist playlist) {
    if (_opening) return;
    final index = playlist.index;
    if (index > _at) {
      // mpv moved to the next item on its own.
      _at = index;
      _advanced.add(index);
    } else if (index < _at) {
      // Our own dropFirst shifted the window.
      _at = index;
    }
  }

  @override
  Future<void> open(List<Track> window, {Duration start = Duration.zero, bool play = true}) async {
    _opening = true;
    try {
      _ids = [for (final t in window) t.id];
      _at = 0;
      await _player.open(
        mk.Playlist([
          for (final (i, t) in window.indexed) _media(t, start: i == 0 ? start : Duration.zero),
        ]),
        play: play,
      );
      await _player.setPlaylistMode(mk.PlaylistMode.none);
    } finally {
      // Late playlist events from the previous window arrive in the next
      // few milliseconds; let them pass before trusting index changes again.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      _opening = false;
    }
  }

  @override
  Future<void> setNext(Track? track) async {
    final wantId = track?.id;
    final haveId = _ids.length > _at + 1 ? _ids[_at + 1] : null;
    if (wantId == haveId) return;
    if (haveId != null) {
      await _player.remove(_at + 1);
      _ids.removeRange(_at + 1, _ids.length);
    }
    if (track != null) {
      await _player.add(_media(track));
      _ids.add(track.id);
    }
  }

  @override
  Future<void> dropFirst() async {
    if (_ids.length < 2 || _at < 1) return;
    await _player.remove(0);
    _ids.removeAt(0);
    _at = 0;
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume((volume.clamp(0.0, 1.0)) * 100);

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    for (final c in [_playing, _position, _advanced, _completed, _buffering, _errors]) {
      await c.close();
    }
  }
}
