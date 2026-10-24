/// A playable track. Plain Dart so `core/` stays Flutter-free.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumId,
    required this.albumTitle,
    required this.duration,
  });

  final String id;
  final String title;
  final String artist;
  final String albumId;
  final String albumTitle;
  final Duration duration;
}
