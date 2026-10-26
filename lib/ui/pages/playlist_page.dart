import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/providers/playlist_actions.dart';
import '../../app/providers/session_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/playlist.dart';
import '../../core/models/track.dart';
import '../widgets/art_tile.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import '../widgets/shapes/morph_path.dart';
import 'album_page.dart' show goBack;
import 'page_frame.dart';
import 'widgets/song_row.dart';

/// A playlist: cover, play and shuffle, and its songs. Your own playlists can
/// be renamed, made public or private, deleted, and have songs dragged into a
/// new order or removed; smart playlists and other people's are read-only.
class PlaylistPage extends ConsumerWidget {
  const PlaylistPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(playlistDetailProvider(playlistId));
    ref.listen(playlistDetailProvider(playlistId), (_, next) {
      next.whenData((d) => ref.read(likedProvider.notifier).seed(d.tracks, addOnly: true));
    });
    return PageFrame(
      child: detail.hasError && !detail.hasValue
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
              child: ErrorPanel(error: detail.error!, onRetry: () => ref.invalidate(playlistDetailProvider(playlistId))),
            )
          : !detail.hasValue
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
                  child: Column(
                    children: [
                      const SkeletonBox(width: 220, height: 220, radius: 56),
                      const SizedBox(height: 28),
                      for (var i = 0; i < 6; i++) ...[
                        const SkeletonBox(height: 52, radius: 22),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                )
              : _Body(detail: detail.requireValue),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.detail});

  final PlaylistDetail detail;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  /// The songs as arranged on screen: ahead of the server's copy for a moment
  /// after a drag or a remove, so the list does not jump while it saves.
  List<Track>? _local;

  Playlist get _playlist => widget.detail.playlist;
  List<Track> get _tracks => _local ?? widget.detail.tracks;

  @override
  void didUpdateWidget(_Body old) {
    super.didUpdateWidget(old);
    // The server's list arrived: it is the truth now.
    if (old.detail != widget.detail) _local = null;
  }

  bool get _canEdit => _playlist.canEdit(ref.read(sessionProvider)?.username ?? '');

  /// [to] is already the position after the song has left [from].
  Future<void> _reorder(int from, int to) async {
    if (from == to) return;
    final next = [..._tracks];
    next.insert(to, next.removeAt(from));
    setState(() => _local = next);
    if (!await ref.read(playlistActionsProvider).reorder(_playlist, next) && mounted) {
      setState(() => _local = null); // put back what the server has
    }
  }

  Future<void> _remove(int index) async {
    final next = [..._tracks]..removeAt(index);
    setState(() => _local = next);
    if (!await ref.read(playlistActionsProvider).removeAt(_playlist, index) && mounted) {
      setState(() => _local = null);
    }
  }

  Future<void> _rename() async {
    final name = await showDialog<String>(context: context, builder: (_) => _RenameDialog(initial: _playlist.name));
    if (name != null) await ref.read(playlistActionsProvider).rename(_playlist, name);
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(context: context, builder: (_) => _DeleteDialog(name: _playlist.name));
    if (yes != true || !mounted) return;
    if (await ref.read(playlistActionsProvider).delete(_playlist) && mounted) goBack(context);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    final tracks = _tracks;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final player = ref.read(playbackProvider.notifier);
    final editable = _canEdit;
    final total = tracks.fold<Duration>(Duration.zero, (a, t) => a + t.duration);
    final minutes = total.inMinutes;
    final length = minutes >= 60 ? '${minutes ~/ 60} hr ${minutes % 60} min' : '$minutes min';

    final cover = ArtTile(
      coverArt: playlist.coverArt,
      seedKey: playlist.id,
      resolution: 800,
      size: 220,
      params: ShapeKind.forKey(playlist.id).params,
      morph: 0,
      spin: 0,
      shadowAlpha: .4,
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playlist.owner == null ? 'PLAYLIST' : 'PLAYLIST · ${playlist.owner}'.toUpperCase(),
          style: text.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: LetterReveal(text: playlist.name, style: text.displaySmall, delay: const Duration(milliseconds: 100)),
        ),
        const SizedBox(height: 6),
        Text(
          '${tracks.length} song${tracks.length == 1 ? '' : 's'} · $length',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ExpressivePillButton(
              label: 'Play',
              icon: Icons.play_arrow_rounded,
              onPressed: () => tracks.isEmpty ? null : player.playTracks(tracks),
            ),
            ExpressivePillButton(
              label: 'Shuffle',
              icon: Icons.shuffle_rounded,
              glyph: GlyphKind.shuffle,
              filled: false,
              onPressed: () => tracks.isEmpty ? null : player.playTracks(tracks, shuffle: true),
            ),
            if (editable) ...[
              _VisibilityPill(
                isPublic: playlist.isPublic,
                onToggle: () => ref.read(playlistActionsProvider).setPublic(playlist, !playlist.isPublic),
              ),
              IconButton.filledTonal(tooltip: 'Rename', onPressed: _rename, icon: const Icon(Icons.edit_rounded)),
              IconButton.filledTonal(tooltip: 'Delete playlist', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ],
        ),
        if (!editable) ...[
          const SizedBox(height: 16),
          _ReadOnlyNote(playlist: playlist),
        ],
      ],
    );

    final header = LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 720;
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [cover, const SizedBox(width: 32), Expanded(child: info)],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Center(child: cover), const SizedBox(height: 20), info],
              );
      },
    );

    return CustomScrollView(
      scrollCacheExtent: const ScrollCacheExtent.pixels(700),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 36, 32, 28),
          sliver: SliverToBoxAdapter(child: header),
        ),
        if (tracks.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 0, 32, PageFrame.bottomClearance),
            sliver: SliverToBoxAdapter(
              child: EmptyPanel(
                icon: Icons.queue_music_rounded,
                title: 'This playlist is empty',
                message: 'Right-click a song anywhere and choose "Add to playlist…".',
              ),
            ),
          )
        else if (editable)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 32, PageFrame.bottomClearance),
            sliver: SliverReorderableList(
              itemCount: tracks.length,
              itemExtent: SongRow.height,
              onReorderItem: _reorder,
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 6,
                borderRadius: BorderRadius.circular(24),
                child: child,
              ),
              itemBuilder: (context, i) => KeyedSubtree(
                key: ValueKey('${tracks[i].id}#$i'),
                child: SongRow(
                  track: tracks[i],
                  onPlay: () => player.playTracks(tracks, index: i),
                  onRemove: () => _remove(i),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Tooltip(
                        message: 'Drag to reorder',
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.drag_indicator_rounded, size: 20, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 32, PageFrame.bottomClearance),
            sliver: SliverFixedExtentList(
              itemExtent: SongRow.height,
              delegate: SliverChildBuilderDelegate(
                (context, i) => SongRow(track: tracks[i], onPlay: () => player.playTracks(tracks, index: i)),
                childCount: tracks.length,
              ),
            ),
          ),
      ],
    );
  }
}

/// Says why a playlist cannot be edited.
class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final smart = playlist.readonly;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(smart ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              smart
                  ? 'This is a smart playlist. The server builds it from rules, so its songs can\'t be changed here.'
                  : 'This playlist belongs to ${playlist.owner}, so you can only listen to it.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Private" / "Public": a toggle for who else on the server can see the playlist.
class _VisibilityPill extends StatelessWidget {
  const _VisibilityPill({required this.isPublic, required this.onToggle});

  final bool isPublic;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      toggled: isPublic,
      label: isPublic ? 'Public playlist' : 'Private playlist',
      hint: 'Switches who can see it',
      excludeSemantics: true,
      onTap: onToggle,
      child: Tooltip(
        message: isPublic
            ? 'Public: everyone on the server can see it. Tap to make it private.'
            : 'Private: only you can see it. Tap to make it public.',
        child: Pressable(
          onTap: onToggle,
          builder: (context, s) => AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isPublic
                  ? scheme.primaryContainer
                  : (s.hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(s.pressed ? 12 : 20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: isPublic ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  isPublic ? 'Public' : 'Private',
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isPublic ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Rename playlist'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Delete "$name"?'),
      content: const Text('This removes the playlist from your server. The songs stay in your library.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
