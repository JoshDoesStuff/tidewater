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

  void clear() {
    if (state.isNotEmpty) state = const TrackSelection();
  }
}

extension on List<Track> {
  int indexWhereId(String? id) => id == null ? -1 : indexWhere((t) => t.id == id);
}

final selectionProvider = NotifierProvider<SelectionNotifier, TrackSelection>(SelectionNotifier.new);
