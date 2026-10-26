import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:tidewater/core/playback/queue_engine.dart';
import 'package:tidewater/core/playback/simulated_engine.dart';

/// A backend where loading a track takes a while, and which counts the loads.
class _SlowBackend extends SimulatedBackend {
  _SlowBackend() : super(tick: const Duration(milliseconds: 5));

  int opens = 0;

  @override
  Future<void> open(List<Track> window, {Duration start = Duration.zero, bool play = true}) async {
    opens++;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return super.open(window, start: start, play: play);
  }
}

Track _t(int i) => Track(
      id: 't$i',
      title: 'Track $i',
      artist: 'A',
      albumId: 'a',
      albumTitle: 'Album',
      duration: const Duration(seconds: 200),
    );

void main() {
  test('mashing Next loads only the last track, not every one in turn', () async {
    final backend = _SlowBackend();
    final engine = QueueEngine(backend: backend);
    await engine.playQueue([for (var i = 0; i < 12; i++) _t(i)]);
    expect(backend.opens, 1);

    final skips = [for (var i = 0; i < 6; i++) engine.next()];
    // The screen follows each press at once...
    await Future<void>.delayed(Duration.zero);
    await Future.wait(skips);
    expect(engine.state.index, 6);
    expect(engine.state.track?.id, 't6');
    // ...but only one more track was actually opened.
    expect(backend.opens, 2, reason: 'one open for the last of six skips');
    await engine.dispose();
  });

  test('Previous right after Next goes back a track instead of restarting', () async {
    final backend = _SlowBackend();
    final engine = QueueEngine(backend: backend);
    await engine.playQueue([for (var i = 0; i < 5; i++) _t(i)]);
    await engine.next();
    final skips = [engine.next(), engine.previous()];
    await Future.wait(skips);
    expect(engine.state.index, 1);
    await engine.dispose();
  });
}
