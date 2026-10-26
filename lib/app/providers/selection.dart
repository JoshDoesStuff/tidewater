import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';

/// The songs picked on the current page (Ctrl+click, Shift+click for a range).
///
/// Each pick has a key: the song's id, except where a song can be on the page
/// twice (a playlist), where the key also says which row, so only that row is picked.
class TrackSelection {
  const TrackSelection({this.tracks = const [], this.keys = const [], this.anchor});

  /// In the order they were picked (a range goes in list order).
  final List<Track> tracks;

  /// [tracks]' keys, in the same order.
  final List<String> keys;

  /// Where a Shift+click range starts: the key clicked last.
  final String? anchor;

  bool get isEmpty => tracks.isEmpty;
  bool get isNotEmpty => tracks.isNotEmpty;
  int get length => tracks.length;
  bool contains(String key) => keys.contains(key);
}

class SelectionNotifier extends Notifier<TrackSelection> {
  @override
  TrackSelection build() => const TrackSelection();

  /// Adds the song, or takes it out when it is already picked.
  void toggle(Track track, {String? key}) {
    final k = key ?? track.id;
    final at = state.keys.indexOf(k);
    if (at >= 0) {
      state = TrackSelection(
        tracks: [...state.tracks]..removeAt(at),
        keys: [...state.keys]..removeAt(at),
        anchor: k,
      );
    } else {
      state = TrackSelection(tracks: [...state.tracks, track], keys: [...state.keys, k], anchor: k);
    }
  }

  /// Picks everything between the last song clicked and [track] in [within]
  /// ([withinKeys] are their keys, when they are not just the ids).
  /// With no starting point, it just picks [track].
  void rangeTo(Track track, List<Track> within, {String? key, List<String>? withinKeys}) {
    final keys = withinKeys ?? [for (final t in within) t.id];
    final from = state.anchor == null ? -1 : keys.indexOf(state.anchor!);
    final to = keys.indexOf(key ?? track.id);
    if (from < 0 || to < 0) return toggle(track, key: key);
    final lo = from < to ? from : to;
    final hi = from < to ? to : from;
    final have = state.keys.toSet();
    state = TrackSelection(
      tracks: [...state.tracks, for (var i = lo; i <= hi; i++) if (!have.contains(keys[i])) within[i]],
      keys: [...state.keys, for (var i = lo; i <= hi; i++) if (!have.contains(keys[i])) keys[i]],
      anchor: state.anchor,
    );
  }

  void selectAll(List<Track> tracks, {List<String>? keys}) {
    final k = keys ?? [for (final t in tracks) t.id];
    state = TrackSelection(tracks: List.of(tracks), keys: k, anchor: k.isEmpty ? null : k.last);
  }

  void clear() {
    if (state.isNotEmpty) state = const TrackSelection();
  }
}

final selectionProvider = NotifierProvider<SelectionNotifier, TrackSelection>(SelectionNotifier.new);

/// What Ctrl+A picks on the current page, and what "Remove" does there (a playlist
/// can take songs out; most pages cannot). Pages register theirs with `SelectionScope`.
class SelectionScopeData {
  const SelectionScopeData({required this.tracks, this.keys, this.remove, this.removeLabel = 'Remove'});

  final List<Track> tracks;

  /// Row keys when the ids are not enough (see [TrackSelection]); null: the ids.
  final List<String>? keys;

  /// Takes the picked rows out; gets their keys.
  final Future<void> Function(List<String> pickedKeys)? remove;
  final String removeLabel;
}

class SelectionScopeNotifier extends Notifier<SelectionScopeData?> {
  Object? _owner;

  @override
  SelectionScopeData? build() => null;

  void set(Object owner, SelectionScopeData data) {
    if (!ref.mounted) return;
    _owner = owner;
    state = data;
  }

  /// Only the page that set the scope can take it away (a new page may already have its own).
  void release(Object owner) {
    if (!ref.mounted) return;
    if (_owner == owner) {
      _owner = null;
      state = null;
    }
  }
}

final selectionScopeProvider = NotifierProvider<SelectionScopeNotifier, SelectionScopeData?>(SelectionScopeNotifier.new);

/// The rows picked in the queue panel, by position (a song can be queued twice).
class QueueSelectionNotifier extends Notifier<Set<int>> {
  int? anchor;

  @override
  Set<int> build() => const {};

  void toggle(int i) {
    anchor = i;
    state = state.contains(i) ? ({...state}..remove(i)) : {...state, i};
  }

  /// Picks from the last row clicked (or [start], the playing row, when none) to [i].
  void rangeTo(int i, {int? start}) {
    final from = anchor ?? start;
    if (from == null) return toggle(i);
    anchor = from;
    final lo = from < i ? from : i;
    final hi = from < i ? i : from;
    state = {...state, for (var k = lo; k <= hi; k++) k};
  }

  void selectAll(int count) => state = {for (var k = 0; k < count; k++) k};

  void clear() {
    anchor = null;
    if (state.isNotEmpty) state = const {};
  }
}

final queueSelectionProvider = NotifierProvider<QueueSelectionNotifier, Set<int>>(QueueSelectionNotifier.new);
