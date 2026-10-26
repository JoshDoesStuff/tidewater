import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';

/// The songs picked on the current page (Ctrl+click, Shift+click for a range).
class TrackSelection {
  const TrackSelection({this.tracks = const [], this.anchor});

  /// In the order they were picked (a range goes in list order).
  final List<Track> tracks;

  /// Where a Shift+click range starts: the song clicked last.
  final String? anchor;

  bool get isEmpty => tracks.isEmpty;
  bool get isNotEmpty => tracks.isNotEmpty;
  int get length => tracks.length;
  bool contains(String id) => tracks.any((t) => t.id == id);
}

class SelectionNotifier extends Notifier<TrackSelection> {
  @override
  TrackSelection build() => const TrackSelection();

  /// Adds the song, or takes it out when it is already picked.
  void toggle(Track track) {
    if (state.contains(track.id)) {
      state = TrackSelection(tracks: [for (final t in state.tracks) if (t.id != track.id) t], anchor: track.id);
    } else {
      state = TrackSelection(tracks: [...state.tracks, track], anchor: track.id);
    }
  }

  /// Picks everything between the last song clicked and [track] in [within].
  /// With no starting point, it just picks [track].
  void rangeTo(Track track, List<Track> within) {
    final from = within.indexWhereId(state.anchor);
    final to = within.indexWhereId(track.id);
    if (from < 0 || to < 0) return toggle(track);
    final lo = from < to ? from : to;
    final hi = from < to ? to : from;
    final have = {for (final t in state.tracks) t.id};
    state = TrackSelection(
      tracks: [...state.tracks, for (final t in within.sublist(lo, hi + 1)) if (!have.contains(t.id)) t],
      anchor: state.anchor,
    );
  }

  void selectAll(List<Track> tracks) =>
      state = TrackSelection(tracks: List.of(tracks), anchor: tracks.isEmpty ? null : tracks.last.id);

  void clear() {
    if (state.isNotEmpty) state = const TrackSelection();
  }
}

extension on List<Track> {
  int indexWhereId(String? id) => id == null ? -1 : indexWhere((t) => t.id == id);
}

final selectionProvider = NotifierProvider<SelectionNotifier, TrackSelection>(SelectionNotifier.new);

/// What Ctrl+A picks on the current page, and what "Remove" does there (a playlist
/// can take songs out; most pages cannot). Pages register theirs with `SelectionScope`.
class SelectionScopeData {
  const SelectionScopeData({required this.tracks, this.remove, this.removeLabel = 'Remove'});

  final List<Track> tracks;
  final Future<void> Function(List<Track> picked)? remove;
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

  void rangeTo(int i) {
    final from = anchor;
    if (from == null) return toggle(i);
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
