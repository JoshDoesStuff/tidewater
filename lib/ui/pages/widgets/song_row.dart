import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/playback_providers.dart';
import '../../../app/providers/selection.dart';
import '../../../app/theme/motion.dart';
import '../../../core/models/track.dart';
import '../../shell/shell_keys.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/effects/eq_bars.dart';
import '../../widgets/effects/ripple.dart';
import '../../widgets/link_text.dart';
import '../../widgets/name_text.dart';
import '../../widgets/pressable.dart';
import '../../widgets/track_drag.dart';
import '../../widgets/track_menu.dart';
import '../../widgets/heart_button.dart';

/// One song in the Library's Songs list: cover, title, artist and album,
/// heart and length. Tap plays from here; the playing song is highlighted.
class SongRow extends ConsumerWidget {
  const SongRow({
    super.key,
    required this.track,
    required this.onPlay,
    this.onRemove,
    this.leading,
    this.siblings,
    this.pickKey,
    this.siblingKeys,
    this.draggable = true,
  });

  static const height = 60.0;

  final Track track;
  final VoidCallback onPlay;

  /// Inside a playlist: "Remove from this playlist" joins the menu.
  final VoidCallback? onRemove;

  /// Before the cover (a drag handle while a playlist is being arranged).
  final Widget? leading;

  /// The list this row is in, so Shift+click can pick a range.
  final List<Track>? siblings;

  /// Tells this row from another with the same song (in a playlist), so picking one
  /// picks only it; [siblingKeys] are the keys of [siblings]. Null: the song's id.
  final String? pickKey;
  final List<String>? siblingKeys;

  /// Whether it can be picked up and dropped on a playlist or the mini player.
  final bool draggable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = ref.watch(currentTrackIdProvider) == track.id;
    final playing =
        current && ref.watch(playbackProvider.select((s) => s.playing));
    final liked = ref.watch(likedProvider.select((s) => s.contains(track.id)));
    final player = ref.read(playbackProvider.notifier);
    final picked = ref.watch(selectionProvider.select((s) => s.contains(pickKey ?? track.id)));
    final picking = ref.watch(selectionProvider.select((s) => s.isNotEmpty));
    final selection = ref.read(selectionProvider.notifier);
    // A row inside the picked ones stands for all of them; any other stands alone.
    List<Track> group() {
      final s = ref.read(selectionProvider);
      return s.contains(pickKey ?? track.id) ? s.tracks : [track];
    }

    void menu(Offset at) => showTrackMenu(
      context,
      ref,
      at: at,
      tracks: group(),
      onRemove: group().length == 1 ? onRemove : null,
    );
    void tapped() {
      final keys = HardwareKeyboard.instance;
      if (keys.isShiftPressed && siblings != null && picking) {
        selection.rangeTo(track, siblings!, key: pickKey, withinKeys: siblingKeys);
      } else if (keys.isControlPressed || keys.isMetaPressed || keys.isShiftPressed || picking) {
        selection.toggle(track, key: pickKey);
      } else {
        current ? player.toggle() : onPlay();
      }
    }

    return TrackDragSource(
      enabled: draggable,
      drag: TrackDrag.tracks(group()),
      child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (d) => menu(d.globalPosition),
      child: Pressable(
        onTap: tapped,
        semanticLabel:
            '${track.title}, ${track.artist}, ${formatDuration(track.duration)}${current ? ', playing' : ''}${picked ? ', selected' : ''}',
        builder: (context, s) => AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          height: height,
          padding: const EdgeInsets.only(left: 10, right: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: picked
                ? scheme.secondaryContainer
                : current
                ? scheme.primaryContainer.withValues(alpha: .55)
                : (s.hovered
                      ? scheme.surfaceContainerHigh
                      : scheme.surfaceContainerHigh.withValues(alpha: 0)),
            borderRadius: BorderRadius.circular(s.pressed ? 14 : 24),
          ),
          child: Ripple(
            color: scheme.onSurface,
            child: Row(
              children: [
                ?leading,
                SizedBox.square(
                  dimension: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CoverArt(
                          coverArt: track.coverArt,
                          seedKey: track.albumId,
                          resolution: 150,
                        ),
                        if (picked || current || s.hovered)
                          ColoredBox(
                            color: picked ? scheme.primary.withValues(alpha: .9) : scheme.scrim.withValues(alpha: .45),
                            child: Center(
                              child: picked
                                  ? Icon(Icons.check_rounded, size: 24, color: scheme.onPrimary)
                                  : current
                                  ? MiniEq(
                                      animating: playing,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : Icon(
                                      picking ? Icons.radio_button_unchecked_rounded : Icons.play_arrow_rounded,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NameText(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: current ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      LinkText(
                        text: track.artist,
                        onTap: track.artistId == null
                            ? null
                            : () => context.push('/artist/${track.artistId}'),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: LinkText(
                    text: track.albumTitle,
                    onTap: track.albumId.isEmpty
                        ? null
                        : () => context.push('/album/${track.albumId}'),
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: liked || s.hovered || current ? 1 : 0,
                  alwaysIncludeSemantics: true,
                  duration: Motion.of(context, Motion.fast),
                  child: HeartButton(
                    liked: liked,
                    onTap: () => ref.read(likedProvider.notifier).toggle(track),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    formatDuration(track.duration),
                    textAlign: TextAlign.right,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // The menu comes last, after the heart and the length. It only shows on
                // hover, but keeps its place (and stays in the accessibility tree, so
                // hovering never adds and removes nodes).
                AnimatedOpacity(
                  opacity: s.hovered ? 1 : 0,
                  alwaysIncludeSemantics: true,
                  duration: Motion.of(context, Motion.fast),
                  child: Builder(
                    builder: (menuContext) => IconButton(
                      tooltip: 'More',
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final box = menuContext.findRenderObject()! as RenderBox;
                        menu(box.localToGlobal(Offset(0, box.size.height)));
                      },
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
