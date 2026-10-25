import '../models/track.dart';

/// One call to make to the server's `scrobble`.
class ScrobbleEvent {
  const ScrobbleEvent(this.track, {required this.submission, required this.startedAt});

  final Track track;

  /// False = "now playing"; true = count this as a play.
  final bool submission;

  /// When listening to this play began (the `time` the server records).
  final DateTime startedAt;

  @override
  String toString() => 'ScrobbleEvent(${track.id}, ${submission ? 'submission' : 'now playing'})';
}

/// Decides when to scrobble. Navidrome only counts a play when `scrobble` is
/// sent with `submission=true`, so: "now playing" when a track starts, then
/// the submission once the person has actually listened to half of it or four
/// minutes, whichever comes first.
///
/// Listening time is counted from position updates while playing, so pausing
/// does not count, and seeking forward cannot cheat the rule: a jump is not
/// listening. Pure Dart; feed it with [onTrack] and [onPosition].
class ScrobbleTracker {
  ScrobbleTracker({DateTime Function()? now, this.fraction = .5, this.cap = const Duration(minutes: 4)})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final double fraction;
  final Duration cap;

  /// Position steps larger than this are seeks, not listening.
  static const _maxStep = Duration(seconds: 2);

  Track? _track;
  bool _playing = false;
  bool _announced = false;
  bool _submitted = false;
  Duration _heard = Duration.zero;
  Duration? _last;
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// How much of the current play has been heard so far.
  Duration get heard => _heard;

  /// Listening time needed before the play counts.
  Duration thresholdFor(Track t) {
    if (t.duration <= Duration.zero) return cap;
    final half = Duration(microseconds: (t.duration.inMicroseconds * fraction).round());
    return half < cap ? half : cap;
  }

  /// The current track or play/pause state changed.
  List<ScrobbleEvent> onTrack(Track? track, {required bool playing}) {
    final out = <ScrobbleEvent>[];
    if (track?.id != _track?.id) {
      _startPlay(track);
    }
    _playing = playing;
    if (!playing) _last = null;
    _maybeAnnounce(out);
    return out;
  }

  /// Playback position moved (called ~10-30 times a second while playing).
  List<ScrobbleEvent> onPosition(Duration position) {
    final out = <ScrobbleEvent>[];
    final t = _track;
    if (t == null) return out;
    final last = _last;
    _last = position;
    if (!_playing || last == null) return out;
    final step = position - last;
    if (step < Duration.zero && _submitted && position < const Duration(seconds: 3)) {
      // Repeat-one: the track started over after counting, so this is a new play.
      _startPlay(t);
      _maybeAnnounce(out);
      return out;
    }
    if (step > Duration.zero && step <= _maxStep) _heard += step;
    if (!_submitted && _announced && _heard >= thresholdFor(t)) {
      _submitted = true;
      out.add(ScrobbleEvent(t, submission: true, startedAt: _startedAt));
    }
    return out;
  }

  void _startPlay(Track? track) {
    _track = track;
    _announced = false;
    _submitted = false;
    _heard = Duration.zero;
    _last = null;
    _startedAt = _now();
  }

  void _maybeAnnounce(List<ScrobbleEvent> out) {
    final t = _track;
    if (t != null && _playing && !_announced) {
      _announced = true;
      out.add(ScrobbleEvent(t, submission: false, startedAt: _startedAt));
    }
  }
}
