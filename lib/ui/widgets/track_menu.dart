import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../../core/models/track.dart';
import 'playlist_flow.dart';

/// The right-click / "more" menu for one song, or for several (an album, the
/// queue): play next, add to the queue, add to a playlist, go to the album or
/// the artist. [onRemove] adds "Remove from this playlist" (inside a playlist).
Future<void> showTrackMenu(
  BuildContext context,
  WidgetRef ref, {
  required Offset at,
  required List<Track> tracks,
  VoidCallback? onRemove,
}) async {
  if (tracks.isEmpty) return;
  final scheme = Theme.of(context).colorScheme;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final one = tracks.length == 1 ? tracks.single : null;
  Widget item(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface))),
        ],
      );
  final choice = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(Rect.fromLTWH(at.dx, at.dy, 0, 0), Offset.zero & overlay.size),
    color: scheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    items: [
      PopupMenuItem(value: 'next', child: item(Icons.playlist_play_rounded, 'Play next')),
      PopupMenuItem(value: 'queue', child: item(Icons.queue_music_rounded, 'Add to queue')),
      PopupMenuItem(value: 'playlist', child: item(Icons.playlist_add_rounded, 'Add to playlist…')),
      if (one != null && (one.albumId.isNotEmpty || one.artistId != null)) const PopupMenuDivider(),
      if (one != null && one.albumId.isNotEmpty) PopupMenuItem(value: 'album', child: item(Icons.album_rounded, 'Go to album')),
      if (one?.artistId != null) PopupMenuItem(value: 'artist', child: item(Icons.person_rounded, 'Go to artist')),
      if (onRemove != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem(value: 'remove', child: item(Icons.remove_circle_outline_rounded, 'Remove from this playlist')),
      ],
    ],
  );
  if (choice == null || !context.mounted) return;
  final player = ref.read(playbackProvider.notifier);
  switch (choice) {
    case 'next':
      await player.addNext(tracks);
      ref.read(toastProvider.notifier).show(tracks.length == 1 ? 'Playing next.' : 'Playing ${tracks.length} songs next.');
    case 'queue':
      await player.addLast(tracks);
      ref.read(toastProvider.notifier).show(tracks.length == 1 ? 'Added to the queue.' : 'Added ${tracks.length} songs to the queue.');
    case 'playlist':
      await addToPlaylistFlow(context, ref, tracks);
    case 'album':
      context.push('/album/${one!.albumId}');
    case 'artist':
      context.push('/artist/${one!.artistId}');
    case 'remove':
      onRemove?.call();
  }
}

/// The right-click menu for an album, an artist or a playlist: the same things
/// as for songs, on all of its songs, which are fetched when one is chosen.
Future<void> showCollectionMenu(
  BuildContext context,
  WidgetRef ref, {
  required Offset at,
  required Future<List<Track>> Function() load,
  required String openLabel,
  required String openRoute,
  String? artistRoute,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  Widget item(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface))),
        ],
      );
  final choice = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(Rect.fromLTWH(at.dx, at.dy, 0, 0), Offset.zero & overlay.size),
    color: scheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    items: [
      PopupMenuItem(value: 'play', child: item(Icons.play_arrow_rounded, 'Play')),
      PopupMenuItem(value: 'shuffle', child: item(Icons.shuffle_rounded, 'Shuffle')),
      PopupMenuItem(value: 'next', child: item(Icons.playlist_play_rounded, 'Play next')),
      PopupMenuItem(value: 'queue', child: item(Icons.queue_music_rounded, 'Add to queue')),
      PopupMenuItem(value: 'playlist', child: item(Icons.playlist_add_rounded, 'Add to playlist…')),
      const PopupMenuDivider(),
      PopupMenuItem(value: 'open', child: item(Icons.open_in_new_rounded, openLabel)),
      if (artistRoute != null) PopupMenuItem(value: 'artist', child: item(Icons.person_rounded, 'Go to artist')),
    ],
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'open') {
    context.push(openRoute);
    return;
  }
  if (choice == 'artist') {
    context.push(artistRoute!);
    return;
  }
  final player = ref.read(playbackProvider.notifier);
  final toast = ref.read(toastProvider.notifier);
  final List<Track> tracks;
  try {
    tracks = await load();
  } catch (_) {
    toast.show('Couldn\'t get those songs from the server.', error: true);
    return;
  }
  if (tracks.isEmpty) {
    toast.show('Nothing in there.');
    return;
  }
  switch (choice) {
    case 'play':
      await player.playTracks(tracks);
    case 'shuffle':
      await player.playTracks(tracks, shuffle: true);
    case 'next':
      await player.addNext(tracks);
      toast.show(tracks.length == 1 ? 'Playing next.' : 'Playing ${tracks.length} songs next.');
    case 'queue':
      await player.addLast(tracks);
      toast.show(tracks.length == 1 ? 'Added to the queue.' : 'Added ${tracks.length} songs to the queue.');
    case 'playlist':
      if (context.mounted) await addToPlaylistFlow(context, ref, tracks);
  }
}
