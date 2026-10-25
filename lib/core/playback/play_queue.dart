import 'dart:math' as math;

import '../models/track.dart';

enum LoopMode {
  off,
  all,
  one;

  LoopMode get next => values[(index + 1) % values.length];
}

/// The play order and where we are in it. Pure Dart, no audio.
///
/// [tracks] is the order the tracks will actually play (shuffled when
/// [shuffled]); [current] is the one playing. Turning shuffle on keeps the
/// current track and shuffles everything else after it; turning it off
/// restores the original order around the current track.
class PlayQueue {
  PlayQueue({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  /// Original (unshuffled) order, minus anything removed.
  List<Track> _original = [];
  List<Track> _order = [];
  int _index = 0;
  bool _shuffled = false;

  List<Track> get tracks => List.unmodifiable(_order);
  int get index => _index;
  bool get isEmpty => _order.isEmpty;
  bool get shuffled => _shuffled;
  Track? get current => _index >= 0 && _index < _order.length ? _order[_index] : null;

  /// What plays after [current] under [repeat] without wrapping, or null.
  Track? peekNext(LoopMode repeat) {
    if (_order.isEmpty) return null;
    if (repeat == LoopMode.one) return current;
    if (_index + 1 < _order.length) return _order[_index + 1];
    if (repeat == LoopMode.all) return _order.length == 1 ? current : _order.first;
    return null;
  }

  /// The track before [current] (wrapping), or null for an empty queue.
  Track? peekPrevious() {
    if (_order.isEmpty) return null;
    return _order[(_index - 1 + _order.length) % _order.length];
  }

  /// Replaces everything and starts at [index] of [tracks] (the order given).
  void replace(List<Track> tracks, {int index = 0, bool shuffle = false}) {
    _original = [...tracks];
    _order = [...tracks];
    _index = tracks.isEmpty ? 0 : index.clamp(0, tracks.length - 1);
    _shuffled = false;
    if (shuffle) setShuffle(true);
  }

  void clear() {
    _original = [];
    _order = [];
    _index = 0;
  }

  /// Moves to the next track. Returns false at the end of the queue (repeat
  /// off). With repeat-all it wraps, reshuffling first when shuffled so every
  /// lap is a new order.
  bool advance(LoopMode repeat) {
    if (_order.isEmpty) return false;
    if (repeat == LoopMode.one) return true;
    if (_index + 1 < _order.length) {
      _index++;
      return true;
    }
    if (repeat == LoopMode.all) {
      if (_shuffled && _order.length > 2) {
        final last = _order.last;
        do {
          _order.shuffle(_random);
        } while (identical(_order.first, last) || _order.first == last);
      }
      _index = 0;
      return true;
    }
    return false;
  }

  /// Moves to the previous track (wrapping to the end).
  bool retreat() {
    if (_order.isEmpty) return false;
    _index = (_index - 1 + _order.length) % _order.length;
    return true;
  }

  /// Jumps to an entry of the current order.
  bool jumpTo(int index) {
    if (index < 0 || index >= _order.length) return false;
    _index = index;
    return true;
  }

  void setShuffle(bool on) {
    if (on == _shuffled) return;
    final cur = current;
    if (on) {
      if (cur == null) {
        _shuffled = true;
        return;
      }
      final rest = [..._order]..removeAt(_index);
      rest.shuffle(_random);
      _order = [cur, ...rest];
      _index = 0;
    } else {
      // Back to the original order, around what is playing now.
      _order = [..._original];
      _index = cur == null ? 0 : math.max(0, _order.indexOf(cur));
    }
    _shuffled = on;
  }

  /// Inserts right after the current track (Play next).
  void addNext(List<Track> tracks) {
    if (tracks.isEmpty) return;
    if (_order.isEmpty) {
      replace(tracks);
      return;
    }
    _order.insertAll(_index + 1, tracks);
    final at = _original.indexOf(current!);
    _original.insertAll(at < 0 ? _original.length : at + 1, tracks);
  }

  /// Appends to the end (Add to queue).
  void addLast(List<Track> tracks) {
    if (tracks.isEmpty) return;
    if (_order.isEmpty) {
      replace(tracks);
      return;
    }
    _order.addAll(tracks);
    _original.addAll(tracks);
  }

  /// Removes the entry at [index] of the play order. Removing the current
  /// track leaves the next one current (or the last, at the end).
  void removeAt(int index) {
    if (index < 0 || index >= _order.length) return;
    final gone = _order.removeAt(index);
    _original.remove(gone);
    if (index < _index) {
      _index--;
    } else if (_index >= _order.length) {
      _index = math.max(0, _order.length - 1);
    }
  }

  /// Moves an entry of the play order (drag to reorder), keeping [current].
  void move(int from, int to) {
    if (from < 0 || from >= _order.length || to < 0 || to >= _order.length || from == to) return;
    final cur = _index;
    final t = _order.removeAt(from);
    _order.insert(to, t);
    if (cur == from) {
      _index = to;
    } else if (from < cur && to >= cur) {
      _index = cur - 1;
    } else if (from > cur && to <= cur) {
      _index = cur + 1;
    }
    if (!_shuffled) _original = [..._order];
  }
}
