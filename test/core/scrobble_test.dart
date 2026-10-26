import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:tidewater/core/playback/scrobble_tracker.dart';

Track _t(String id, int seconds) => Track(
      id: id,
      title: id,
      artist: 'x',
      albumId: 'al',
      albumTitle: 'al',
      duration: Duration(seconds: seconds),
    );

/// Plays [track] from [from] for [seconds] of real listening, 250 ms steps.
List<ScrobbleEvent> listen(ScrobbleTracker s, int seconds, {Duration from = Duration.zero}) {
  final out = <ScrobbleEvent>[];
  var p = from;
  for (var i = 0; i < seconds * 4; i++) {
    p += const Duration(milliseconds: 250);
    out.addAll(s.onPosition(p));
  }
  return out;
}

void main() {
  test('announces "now playing" when a track starts playing, not before', () {
    final s = ScrobbleTracker();
    final a = _t('a', 200);
    expect(s.onTrack(a, playing: false), isEmpty);
    final started = s.onTrack(a, playing: true);
    expect(started.single.track.id, 'a');
    expect(started.single.submission, isFalse);
    expect(s.onTrack(a, playing: true), isEmpty, reason: 'only once per play');
  });

  test('counts the play after half the track', () {
    final s = ScrobbleTracker();
    final a = _t('a', 200);
    s.onTrack(a, playing: true);
    s.onPosition(Duration.zero);
    expect(listen(s, 99), isEmpty);
    final out = listen(s, 3, from: const Duration(seconds: 99));
    expect(out.single.submission, isTrue);
    expect(out.single.track.id, 'a');
  });

  test('long tracks count after four minutes, not half', () {
    final s = ScrobbleTracker();
    final a = _t('long', 30 * 60);
    s.onTrack(a, playing: true);
    s.onPosition(Duration.zero);
    expect(listen(s, 239), isEmpty);
    expect(listen(s, 2, from: const Duration(seconds: 239)).single.submission, isTrue);
    expect(s.thresholdFor(a), const Duration(minutes: 4));
  });

  test('a play is counted once', () {
    final s = ScrobbleTracker();
    s.onTrack(_t('a', 20), playing: true);
    s.onPosition(Duration.zero);
    final all = listen(s, 18);
    expect(all.where((e) => e.submission), hasLength(1));
  });

  test('pausing does not count as listening', () {
    final s = ScrobbleTracker();
    s.onTrack(_t('a', 100), playing: true);
    s.onPosition(Duration.zero);
    listen(s, 30);
    s.onTrack(_t('a', 100), playing: false);
    // Position events while paused (a seek bar drag) must not count either.
    for (var i = 0; i < 100; i++) {
      s.onPosition(Duration(seconds: 30 + i));
    }
    s.onTrack(_t('a', 100), playing: true);
    expect(s.heard.inSeconds, inInclusiveRange(29, 30));
  });

  test('seeking forward is not listening', () {
    final s = ScrobbleTracker();
    s.onTrack(_t('a', 200), playing: true);
    s.onPosition(Duration.zero);
    listen(s, 10);
    // Jump to 3:00 and listen a little: only the little counts.
    expect(s.onPosition(const Duration(seconds: 180)), isEmpty);
    expect(listen(s, 5, from: const Duration(seconds: 180)).where((e) => e.submission), isEmpty);
    expect(s.heard.inSeconds, lessThan(20));
  });

  test('skipping before half does not count the play, and the next track starts fresh', () {
    final s = ScrobbleTracker();
    final a = _t('a', 200);
    final b = _t('b', 200);
    s.onTrack(a, playing: true);
    s.onPosition(Duration.zero);
    expect(listen(s, 20).where((e) => e.submission), isEmpty);
    final started = s.onTrack(b, playing: true);
    expect(started.single.track.id, 'b');
    expect(s.heard, Duration.zero);
    s.onPosition(Duration.zero);
    expect(listen(s, 101).where((e) => e.submission).single.track.id, 'b');
  });

  test('repeat-one counts every lap as its own play', () {
    final s = ScrobbleTracker();
    final a = _t('a', 20);
    s.onTrack(a, playing: true);
    s.onPosition(Duration.zero);
    final first = listen(s, 11);
    expect(first.where((e) => e.submission), hasLength(1));
    // Track ends (position near 20 s) and restarts at zero.
    listen(s, 9, from: const Duration(seconds: 11));
    final second = <ScrobbleEvent>[...s.onPosition(Duration.zero), ...listen(s, 11)];
    expect(second.where((e) => !e.submission), hasLength(1), reason: 'announces again');
    expect(second.where((e) => e.submission), hasLength(1), reason: 'counts again');
  });

  test('the play remembers when it started', () {
    var clock = DateTime.utc(2026, 10, 25, 12);
    final s = ScrobbleTracker(now: () => clock);
    final ev = s.onTrack(_t('a', 100), playing: true).single;
    expect(ev.startedAt, DateTime.utc(2026, 10, 25, 12));
    clock = clock.add(const Duration(minutes: 1));
    s.onPosition(Duration.zero);
    final done = listen(s, 51).singleWhere((e) => e.submission);
    expect(done.startedAt, DateTime.utc(2026, 10, 25, 12), reason: 'start of the play, not when it counted');
  });

  test('an unknown duration falls back to the four-minute cap', () {
    expect(ScrobbleTracker().thresholdFor(_t('a', 0)), const Duration(minutes: 4));
  });

  test('nothing happens with no track', () {
    final s = ScrobbleTracker();
    expect(s.onTrack(null, playing: false), isEmpty);
    expect(s.onPosition(const Duration(seconds: 1)), isEmpty);
  });
}
