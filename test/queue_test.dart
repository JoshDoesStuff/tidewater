import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:tidewater/core/playback/play_queue.dart';
import 'package:tidewater/core/playback/simulated_engine.dart';

Track _t(String id, {int ms = 60}) => Track(
      id: id,
      title: id,
      artist: 'x',
      albumId: 'al',
      albumTitle: 'al',
      duration: Duration(milliseconds: ms),
    );

List<String> _ids(Iterable<Track> t) => [for (final x in t) x.id];

void main() {
  gaplessStateTests();
  group('PlayQueue', () {
    final abc = [_t('a'), _t('b'), _t('c')];

    PlayQueue make({int index = 0}) => PlayQueue(random: Random(7))..replace(abc, index: index);

    test('replace picks the start and reports the current track', () {
      final q = make(index: 1);
      expect(q.current?.id, 'b');
      expect(_ids(q.tracks), ['a', 'b', 'c']);
      expect(PlayQueue().current, isNull);
    });

    test('peekNext follows the repeat mode without moving', () {
      final q = make(index: 2);
      expect(q.peekNext(LoopMode.off), isNull);
      expect(q.peekNext(LoopMode.all)?.id, 'a');
      expect(q.peekNext(LoopMode.one)?.id, 'c');
      expect(q.index, 2);
    });

    test('advance stops at the end, wraps with repeat-all, stays with repeat-one', () {
      final q = make();
      expect(q.advance(LoopMode.off), isTrue);
      expect(q.advance(LoopMode.off), isTrue);
      expect(q.current?.id, 'c');
      expect(q.advance(LoopMode.off), isFalse);
      expect(q.current?.id, 'c');
      expect(q.advance(LoopMode.all), isTrue);
      expect(q.current?.id, 'a');
      expect(q.advance(LoopMode.one), isTrue);
      expect(q.current?.id, 'a');
    });

    test('retreat wraps to the end', () {
      final q = make();
      q.retreat();
      expect(q.current?.id, 'c');
    });

    test('shuffle keeps the current track first and the same tracks', () {
      final q = PlayQueue(random: Random(3))..replace([for (var i = 0; i < 20; i++) _t('t$i')], index: 5);
      q.setShuffle(true);
      expect(q.current?.id, 't5');
      expect(q.index, 0);
      expect(q.tracks.length, 20);
      expect({..._ids(q.tracks)}.length, 20);
      expect(_ids(q.tracks), isNot([for (var i = 5; i < 20; i++) 't$i', for (var i = 0; i < 5; i++) 't$i']));
    });

    test('shuffle off restores the original order around the current track', () {
      final q = PlayQueue(random: Random(3))..replace([for (var i = 0; i < 10; i++) _t('t$i')], index: 2);
      q.setShuffle(true);
      q.advance(LoopMode.off);
      q.advance(LoopMode.off);
      final playing = q.current!.id;
      q.setShuffle(false);
      expect(_ids(q.tracks), [for (var i = 0; i < 10; i++) 't$i']);
      expect(q.current?.id, playing);
    });

    test('a shuffled queue gets a new order each lap and never repeats the last track first', () {
      final q = PlayQueue(random: Random(1))..replace([for (var i = 0; i < 6; i++) _t('t$i')]);
      q.setShuffle(true);
      for (var lap = 0; lap < 20; lap++) {
        while (q.index + 1 < q.tracks.length) {
          q.advance(LoopMode.all);
        }
        final last = q.current!.id;
        q.advance(LoopMode.all);
        expect(q.index, 0);
        expect(q.current!.id, isNot(last));
      }
    });

    test('addNext goes right after the current track, addLast to the end', () {
      final q = make();
      q.addNext([_t('x'), _t('y')]);
      q.addLast([_t('z')]);
      expect(_ids(q.tracks), ['a', 'x', 'y', 'b', 'c', 'z']);
      expect(q.current?.id, 'a');
    });

    test('adding to an empty queue starts one', () {
      final q = PlayQueue()..addLast([_t('a')]);
      expect(q.current?.id, 'a');
    });

    test('removeAt keeps the same track current', () {
      final q = make(index: 1);
      q.removeAt(0);
      expect(q.current?.id, 'b');
      expect(q.index, 0);
      q.removeAt(1);
      expect(_ids(q.tracks), ['b']);
      q.removeAt(0);
      expect(q.isEmpty, isTrue);
    });

    test('removing the current track moves to the next one', () {
      final q = make(index: 1);
      q.removeAt(1);
      expect(q.current?.id, 'c');
    });

    test('move keeps the current track current', () {
      final q = make(index: 1);
      q.move(0, 2); // a goes after c
      expect(_ids(q.tracks), ['b', 'c', 'a']);
      expect(q.current?.id, 'b');
      q.move(2, 0);
      expect(_ids(q.tracks), ['a', 'b', 'c']);
      expect(q.current?.id, 'b');
      q.move(1, 2); // the current track itself
      expect(q.current?.id, 'b');
      expect(q.index, 2);
    });
  });

  group('QueueEngine on the simulated backend', () {
    late SimulatedEngine e;

    setUp(() => e = SimulatedEngine(tick: const Duration(milliseconds: 5), random: Random(2)));
    tearDown(() => e.dispose());

    Future<void> until(bool Function() cond, {int ms = 3000}) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (!cond()) {
        if (DateTime.now().isAfter(end)) fail('timed out waiting');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('plays through the queue by itself and then stops on the first track', () async {
      await e.playQueue([_t('a'), _t('b'), _t('c')]);
      expect(e.state.playing, isTrue);
      await until(() => e.state.index == 2);
      await until(() => !e.state.playing);
      expect(e.state.index, 0, reason: 'rewound to the start, paused');
      expect(e.position, Duration.zero);
    });

    test('repeat-one plays the same track again and again', () async {
      await e.setRepeat(LoopMode.one);
      await e.playQueue([_t('a'), _t('b')]);
      final seen = <int>[];
      final sub = e.positions.listen((p) {
        if (p < const Duration(milliseconds: 15)) seen.add(1);
      });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await sub.cancel();
      expect(e.state.index, 0);
      expect(e.state.playing, isTrue);
    });

    test('repeat-all wraps around', () async {
      await e.setRepeat(LoopMode.all);
      await e.playQueue([_t('a'), _t('b')]);
      await until(() => e.state.index == 1);
      await until(() => e.state.index == 0);
      expect(e.state.playing, isTrue);
    });

    test('next always moves on (even with repeat-one) and wraps at the end', () async {
      await e.setRepeat(LoopMode.one);
      await e.playQueue([_t('a', ms: 5000), _t('b', ms: 5000)]);
      await e.next();
      expect(e.state.track?.id, 'b');
      await e.next();
      expect(e.state.track?.id, 'a');
    });

    test('previous restarts when well into the track, goes back near its start', () async {
      await e.playQueue([_t('a', ms: 9000), _t('b', ms: 9000)], index: 1);
      await e.seek(const Duration(seconds: 5));
      await e.previous();
      expect(e.state.track?.id, 'b');
      expect(e.position, lessThan(const Duration(milliseconds: 200)));
      await e.previous();
      expect(e.state.track?.id, 'a');
    });

    test('pausing and resuming keeps the position', () async {
      await e.playQueue([_t('a', ms: 9000)]);
      await e.seek(const Duration(seconds: 2));
      await e.pause();
      final held = e.position;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(e.position, held);
      await e.play();
      expect(e.state.playing, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(e.position, greaterThan(held));
    });

    test('shuffle reorders what is coming but not what is playing', () async {
      final tracks = [for (var i = 0; i < 12; i++) _t('t$i', ms: 9000)];
      await e.playQueue(tracks, index: 3);
      await e.setShuffle(true);
      expect(e.state.shuffle, isTrue);
      expect(e.state.track?.id, 't3');
      expect(e.state.index, 0);
      expect({..._ids(e.state.queue)}, {..._ids(tracks)});
      await e.setShuffle(false);
      expect(_ids(e.state.queue), _ids(tracks));
      expect(e.state.track?.id, 't3');
    });

    test('shuffle stays on for the next album', () async {
      await e.setShuffle(true);
      await e.playQueue([for (var i = 0; i < 10; i++) _t('t$i', ms: 9000)], index: 4);
      expect(e.state.shuffle, isTrue);
      expect(e.state.track?.id, 't4');
    });

    test('Play next puts a track after the current one and it plays then', () async {
      await e.playQueue([_t('a'), _t('b')]);
      await e.addNext([_t('x')]);
      expect(_ids(e.state.queue), ['a', 'x', 'b']);
      await until(() => e.state.index == 1);
      expect(e.state.track?.id, 'x');
    });

    test('Add to queue goes to the end', () async {
      await e.playQueue([_t('a', ms: 9000), _t('b', ms: 9000)]);
      await e.addLast([_t('z')]);
      expect(_ids(e.state.queue), ['a', 'b', 'z']);
      expect(e.state.index, 0);
    });

    test('removing the playing track starts the next one', () async {
      await e.playQueue([_t('a', ms: 9000), _t('b', ms: 9000)]);
      await e.removeAt(0);
      expect(e.state.track?.id, 'b');
      expect(e.state.playing, isTrue);
    });

    test('removing the last track empties the player', () async {
      await e.playQueue([_t('a', ms: 9000)]);
      await e.removeAt(0);
      expect(e.state.track, isNull);
      expect(e.state.playing, isFalse);
    });

    test('a track that will not play is retried once, then reported and skipped', () async {
      final errors = <String>[];
      e.errors.listen(errors.add);
      await e.playQueue([_t('a', ms: 9000), _t('b', ms: 9000)]);
      final backend = _backendOf(e);
      backend.emitError('failed a');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(e.state.index, 0, reason: 'first failure: try again');
      expect(e.state.playing, isTrue);
      backend.emitError('failed a');
      await until(() => e.state.index == 1);
      expect(errors.length, 2);
      expect(e.state.playing, isTrue);
      backend.emitError('failed b');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      backend.emitError('failed b');
      await until(() => !e.state.playing);
      expect(e.state.index, 1, reason: 'last track: stop instead of looping on errors');
    });

    test('restore loads a session without playing and resumes from the saved position', () async {
      await e.restore([_t('a', ms: 9000), _t('b', ms: 9000)], index: 1, position: const Duration(seconds: 3));
      expect(e.state.track?.id, 'b');
      expect(e.state.playing, isFalse);
      expect(e.position, const Duration(seconds: 3));
      await e.play();
      expect(e.state.playing, isTrue);
      expect(e.position, greaterThanOrEqualTo(const Duration(seconds: 3)));
    });

    test('seeking while nothing is open is remembered for when play starts', () async {
      await e.restore([_t('a', ms: 9000)]);
      await e.seek(const Duration(seconds: 4));
      expect(e.position, const Duration(seconds: 4));
      await e.play();
      expect(e.position, greaterThanOrEqualTo(const Duration(seconds: 4)));
    });

    test('seek is clamped to the track', () async {
      await e.playQueue([_t('a', ms: 1000)]);
      await e.pause();
      await e.seek(const Duration(hours: 1));
      expect(e.position, const Duration(milliseconds: 1000));
      await e.seek(const Duration(seconds: -5));
      expect(e.position, Duration.zero);
    });

    test('stop forgets the queue but keeps volume and shuffle', () async {
      await e.setVolume(.3);
      await e.setShuffle(true);
      await e.playQueue([_t('a'), _t('b')]);
      await e.stop();
      expect(e.state.queue, isEmpty);
      expect(e.state.started, isFalse);
      expect(e.state.volume, .3);
    });

    test('quick commands do not interleave', () async {
      final tracks = [for (var i = 0; i < 6; i++) _t('t$i', ms: 9000)];
      await e.playQueue(tracks);
      await Future.wait([e.next(), e.next(), e.next()]);
      expect(e.state.track?.id, 't3');
    });
  });
}

SimulatedBackend _backendOf(SimulatedEngine e) => e.backendForTest as SimulatedBackend;

void gaplessStateTests() {
  group('play state', () {
    late SimulatedEngine e;

    setUp(() => e = SimulatedEngine(tick: const Duration(milliseconds: 5)));
    tearDown(() => e.dispose());

    test('a brief "not playing" from the backend (loading the next track) is not shown', () async {
      await e.playQueue([_t('a', ms: 9000), _t('b', ms: 9000)]);
      final seen = <bool>[];
      e.states.listen((s) => seen.add(s.playing));
      final backend = e.backendForTest as SimulatedBackend;
      backend.emitPlaying(false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      backend.emitPlaying(true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(e.state.playing, isTrue);
      expect(seen.contains(false), isFalse, reason: 'the play button must not flicker');
    });

    test('a "not playing" that lasts is believed', () async {
      await e.playQueue([_t('a', ms: 9000)]);
      (e.backendForTest as SimulatedBackend).emitPlaying(false);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(e.state.playing, isFalse);
      (e.backendForTest as SimulatedBackend).emitPlaying(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(e.state.playing, isTrue);
    });

    test('pausing is immediate', () async {
      await e.playQueue([_t('a', ms: 9000)]);
      await e.pause();
      expect(e.state.playing, isFalse);
      (e.backendForTest as SimulatedBackend).emitPlaying(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(e.state.playing, isTrue, reason: 'the backend resumed on its own (media key): follow it');
    });
  });
}
