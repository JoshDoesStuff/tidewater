import 'dart:async';

import 'package:tidewater/app/playback/system_media.dart';

/// Stands in for the Windows media overlay: remembers what it was told and
/// lets a test press its buttons.
class RecordingMedia implements SystemMediaControls {
  final log = <String>[];
  final _buttons = StreamController<SystemMediaButton>.broadcast();
  String? lastThumbnail;
  Duration? lastPosition;

  void press(SystemMediaButton b) => _buttons.add(b);

  @override
  Stream<SystemMediaButton> get buttons => _buttons.stream;

  @override
  Future<void> setTrack({required String title, required String artist, required String album, String? thumbnailUri}) async {
    log.add('track:$title|$artist|$album');
    lastThumbnail = thumbnailUri;
  }

  @override
  Future<void> setPlaying(bool playing) async => log.add(playing ? 'playing' : 'paused');

  @override
  Future<void> setTimeline({required Duration position, required Duration duration}) async {
    lastPosition = position;
    log.add('timeline:${position.inSeconds}/${duration.inSeconds}');
  }

  @override
  Future<void> clear() async => log.add('clear');

  @override
  Future<void> dispose() async => _buttons.close();
}
