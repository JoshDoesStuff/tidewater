import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:smtc_windows/smtc_windows.dart';

import 'system_media.dart';

/// [SystemMediaControls] on Windows' System Media Transport Controls: the
/// volume-flyout media card, lock screen and hardware media keys. Every call
/// is guarded: a problem here must never interrupt the music.
class SmtcControls implements SystemMediaControls {
  SmtcControls._(this._smtc) {
    _sub = _smtc.buttonPressStream.listen((b) {
      final mapped = switch (b) {
        PressedButton.play => SystemMediaButton.play,
        PressedButton.pause => SystemMediaButton.pause,
        PressedButton.next => SystemMediaButton.next,
        PressedButton.previous => SystemMediaButton.previous,
        PressedButton.stop => SystemMediaButton.stop,
        _ => null,
      };
      if (mapped != null) _buttons.add(mapped);
    });
  }

  /// Starts SMTC, or returns null (and logs why) when it cannot, so the app
  /// carries on without media keys.
  static Future<SmtcControls?> create() async {
    try {
      await SMTCWindows.initialize();
      final smtc = SMTCWindows(
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          stopEnabled: true,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
        enabled: true,
      );
      return SmtcControls._(smtc);
    } catch (e) {
      debugPrint('[smtc] unavailable: $e');
      return null;
    }
  }

  final SMTCWindows _smtc;
  final _buttons = StreamController<SystemMediaButton>.broadcast();
  StreamSubscription<PressedButton>? _sub;

  @override
  Stream<SystemMediaButton> get buttons => _buttons.stream;

  Future<void> _safe(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('[smtc] $e');
    }
  }

  @override
  Future<void> setTrack({required String title, required String artist, required String album, String? thumbnailUri}) =>
      _safe(() => _smtc.updateMetadata(MusicMetadata(
            title: title,
            artist: artist,
            album: album,
            albumArtist: artist,
            thumbnail: thumbnailUri,
          )));

  @override
  Future<void> setPlaying(bool playing) =>
      _safe(() => _smtc.setPlaybackStatus(playing ? PlaybackStatus.playing : PlaybackStatus.paused));

  @override
  Future<void> setTimeline({required Duration position, required Duration duration}) => _safe(() {
        final end = duration.inMilliseconds;
        return _smtc.updateTimeline(PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: end,
          positionMs: position.inMilliseconds.clamp(0, end),
          minSeekTimeMs: 0,
          maxSeekTimeMs: end,
        ));
      });

  @override
  Future<void> clear() => _safe(() async {
        await _smtc.setPlaybackStatus(PlaybackStatus.stopped);
        await _smtc.clearMetadata();
      });

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _buttons.close();
    await _safe(_smtc.dispose);
  }
}
