/// A music album as the UI needs it. Plain Dart so `core/` stays Flutter-free.
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.track,
    required this.colorA,
    required this.colorB,
  });

  final String id;
  final String title;
  final String artist;

  /// Sample track title (placeholder until real tracks exist).
  final String track;

  /// Placeholder cover-art gradient endpoints as ARGB ints. Replaced by real
  /// cover art (and a scheme generated from it) in later milestones.
  final int colorA;
  final int colorB;
}
