import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/playback/queue_engine.dart';
import 'package:tidewater/core/playback/simulated_engine.dart';

import '../support/fake_library.dart';

void main() {
  test('a track is "buffering" from the skip until its position really moves', () async {
    final backend = SimulatedBackend(tick: const Duration(milliseconds: 5));
    final engine = QueueEngine(backend: backend);
    final seen = <bool>[];
    engine.states.listen((s) => seen.add(s.buffering));

    await engine.playQueue(fakeTracks.take(3).toList());
    expect(engine.state.buffering, isTrue, reason: 'asked to play, nothing has moved yet');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(engine.state.buffering, isFalse, reason: 'the position advanced');

    await engine.next();
    expect(engine.state.buffering, isTrue, reason: 'skipping starts a new wait');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(engine.state.buffering, isFalse);
    await engine.dispose();
  });

  test('pausing while waiting ends the buffering state', () async {
    final engine = QueueEngine(backend: SimulatedBackend(tick: const Duration(seconds: 10)));
    await engine.playQueue(fakeTracks.take(2).toList());
    expect(engine.state.buffering, isTrue);
    await engine.pause();
    expect(engine.state.buffering, isFalse);
    await engine.dispose();
  });
}
