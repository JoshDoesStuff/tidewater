import 'package:flutter_test/flutter_test.dart';
import 'support/placeholder_lyrics.dart';
import 'package:tidewater/core/lyrics/lrc_parser.dart';
import 'package:tidewater/core/playback/simulated_engine.dart';
import 'support/fake_library.dart';
import 'package:tidewater/core/playback/visualizer_source.dart';

void main() {
  group('parseLrc', () {
    test('parses timestamps, sorts, ignores metadata', () {
      final l = parseLrc('[ar:X]\n[00:10.50]b\n[00:02.5]a\n[01:00.05]c');
      expect(l.synced, isTrue);
      expect(l.lines.map((e) => e.text), ['a', 'b', 'c']);
      expect(l.lines[0].time, const Duration(milliseconds: 2500));
      expect(l.lines[1].time, const Duration(milliseconds: 10500));
      expect(l.lines[2].time, const Duration(minutes: 1, milliseconds: 50));
    });

    test('multiple stamps per line and offset', () {
      final l = parseLrc('[offset:500]\n[00:01.00][00:03.00]hey');
      expect(l.lines.length, 2);
      expect(l.lines.first.time, const Duration(milliseconds: 1500));
      expect(l.lines.last.time, const Duration(milliseconds: 3500));
    });

    test('text without timestamps is plain, never synced', () {
      final l = parseLrc('one\ntwo');
      expect(l.synced, isFalse);
      expect(l.lines.length, 2);
      expect(l.activeIndexAt(const Duration(minutes: 5)), 0);
    });

    test('activeIndexAt picks the last started line', () {
      expect(placeholderLyrics.activeIndexAt(Duration.zero), 0);
      expect(placeholderLyrics.activeIndexAt(const Duration(seconds: 28)), 1);
      expect(placeholderLyrics.activeIndexAt(const Duration(seconds: 47)), 1);
      expect(placeholderLyrics.activeIndexAt(const Duration(seconds: 48)), 2);
      expect(placeholderLyrics.activeIndexAt(const Duration(minutes: 10)), placeholderLyrics.lines.length - 1);
    });
  });

  group('SimulatedEngine', () {
    test('plays, pauses, seeks and changes track', () async {
      final e = SimulatedEngine(queue: fakeTracks);
      expect(e.state.playing, isFalse);
      await e.playIndex(3);
      expect(e.state.index, 3);
      expect(e.state.playing, isTrue);
      expect(e.state.started, isTrue);
      await e.seek(const Duration(seconds: 100));
      expect(e.position.inSeconds, inInclusiveRange(100, 101));
      await e.pause();
      expect(e.state.playing, isFalse);
      final held = e.position;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(e.position, held);
      await e.next();
      expect(e.state.index, 4);
      expect(e.position, Duration.zero); // paused, so the clock is stopped
      await e.previous();
      expect(e.state.index, 3);
      await e.dispose();
    });

    test('previous restarts when well into the track', () async {
      final e = SimulatedEngine(queue: fakeTracks);
      await e.playIndex(2);
      await e.seek(const Duration(seconds: 30));
      await e.previous();
      expect(e.state.index, 2);
      expect(e.position, lessThan(const Duration(milliseconds: 100)));
      await e.dispose();
    });

    test('next wraps around the queue', () async {
      final e = SimulatedEngine(queue: fakeTracks);
      await e.playIndex(fakeTracks.length - 1);
      await e.next();
      expect(e.state.index, 0);
      await e.dispose();
    });
  });

  test('visualizer is calm when paused and lively when playing', () async {
    final v = SimulatedVisualizerSource();
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      v.update(playing: true);
    }
    final lively = v.average(0, VisualizerSource.bands);
    expect(lively, greaterThan(.1));
    expect(v.levels.every((l) => l >= 0 && l <= 1), isTrue);
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      v.update(playing: false);
    }
    expect(v.average(0, VisualizerSource.bands), lessThan(lively));
  });
}
