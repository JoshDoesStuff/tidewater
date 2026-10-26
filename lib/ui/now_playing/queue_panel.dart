import '../widgets/name_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/providers/selection.dart';
import '../../app/providers/ui_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/track.dart';
import '../../core/playback/play_queue.dart' show LoopMode;
import '../shell/shell_keys.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/cover_art.dart';
import '../widgets/effects/eq_bars.dart';
import '../widgets/pressable.dart';
import '../widgets/playlist_flow.dart';
import '../widgets/track_menu.dart';

/// The play queue, as a panel that slides in from the right of Now Playing:
/// what is playing, what comes next, tap to jump, drag the handle to reorder,
/// X to remove, plus shuffle and repeat.
class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key, this.docked = false});

  /// Docked beside the player (slides in from the window edge) rather than
  /// floating over it (scales out of the top right).
  final bool docked;

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> {
  static const _rowHeight = 64.0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the playing track near the top (when the panel opens).
  void _revealCurrent() {
    if (!_scroll.hasClients) return;
    final i = ref.read(playbackProvider).index;
    _scroll.jumpTo(
      (i * _rowHeight - _rowHeight).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Positions change when the queue does, so the picked rows are let go.
    ref.listen(playbackProvider.select((s) => s.queue.length), (_, _) => ref.read(queueSelectionProvider.notifier).clear());
    ref.listen(queueOpenProvider, (_, open) {
      if (!open) ref.read(queueSelectionProvider.notifier).clear();
      if (open) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent());
      }
    });
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final open = ref.watch(queueOpenProvider);
    final queue = ref.watch(playbackProvider.select((s) => s.queue));
    final index = ref.watch(playbackProvider.select((s) => s.index));
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final shuffle = ref.watch(playbackProvider.select((s) => s.shuffle));
    final repeat = ref.watch(playbackProvider.select((s) => s.repeat));
    final player = ref.read(playbackProvider.notifier);
    final picked = ref.watch(queueSelectionProvider);
    final pickedNotifier = ref.read(queueSelectionProvider.notifier);
    void tapped(int i) {
      final keys = HardwareKeyboard.instance;
      if (keys.isShiftPressed) {
        pickedNotifier.rangeTo(i, start: index);
      } else if (keys.isControlPressed || keys.isMetaPressed || keys.isShiftPressed || picked.isNotEmpty) {
        pickedNotifier.toggle(i);
      } else {
        i == index ? player.toggle() : player.playIndex(i);
      }
    }

    final remaining = queue
        .skip(index + 1)
        .fold<Duration>(Duration.zero, (a, t) => a + t.duration);

    // Closed: nothing to click, and none of its rows in the accessibility tree
    // (fifty queue rows were being re-announced on every track change).
    return ExcludeSemantics(
      excluding: !open,
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedSlide(
          offset: open
              ? Offset.zero
              : (widget.docked
                    ? const Offset(1.12, 0)
                    : const Offset(.05, -.02)),
          duration: Motion.of(context, Motion.slow),
          curve: Motion.curve(
            context,
            widget.docked ? Motion.emphasized : Motion.spring,
          ),
          child: AnimatedScale(
            scale: open || widget.docked ? 1 : .92,
            alignment: Alignment.topRight,
            duration: Motion.of(context, Motion.slow),
            curve: Motion.curve(context, Motion.spring),
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: Motion.of(
                context,
                widget.docked ? Motion.slow : Motion.medium,
              ),
              curve: Motion.standard,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: .45),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Queue', style: text.titleLarge),
                                Text(
                                  queue.isEmpty
                                      ? 'Nothing queued'
                                      : '${queue.length} track${queue.length == 1 ? '' : 's'}${index + 1 < queue.length ? ' · ${formatDuration(remaining)} left' : ''}',
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Save the queue as a playlist',
                            onPressed: queue.isEmpty
                                ? null
                                : () => addToPlaylistFlow(context, ref, queue),
                            icon: Icon(
                              Icons.playlist_add_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 2),
                          _ToggleChip(
                            glyph: GlyphKind.shuffle,
                            tooltip: shuffle ? 'Shuffle: on' : 'Shuffle: off',
                            selected: shuffle,
                            onTap: player.toggleShuffle,
                          ),
                          const SizedBox(width: 6),
                          _ToggleChip(
                            glyph: repeat == LoopMode.one
                                ? GlyphKind.repeatOne
                                : GlyphKind.repeat,
                            tooltip: switch (repeat) {
                              LoopMode.off => 'Repeat: off',
                              LoopMode.all => 'Repeat: all',
                              LoopMode.one => 'Repeat: this track',
                            },
                            selected: repeat != LoopMode.off,
                            onTap: player.toggleRepeat,
                          ),
                          const SizedBox(width: 6),
                          _ToggleChip(
                            glyph: GlyphKind.close,
                            tooltip: 'Close queue (Q)',
                            selected: false,
                            onTap: () =>
                                ref.read(queueOpenProvider.notifier).set(false),
                          ),
                        ],
                      ),
                    ),
                    if (picked.isNotEmpty)
                      _PickBar(
                        count: picked.length,
                        onClear: pickedNotifier.clear,
                        onRemove: () async {
                          // From the back, so the positions still to go do not move.
                          final gone = picked.toList()..sort((a, b) => b.compareTo(a));
                          pickedNotifier.clear();
                          for (final i in gone) {
                            await player.removeAt(i);
                          }
                          ref.read(toastProvider.notifier).show(gone.length == 1 ? 'Removed 1 song from the queue.' : 'Removed ${gone.length} songs from the queue.');
                        },
                      ),
                    Expanded(
                      child: queue.isEmpty
                          ? Center(
                              child: Text(
                                'Play something to fill the queue.',
                                style: text.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              scrollController: _scroll,
                              buildDefaultDragHandles: false,
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                              itemCount: queue.length,
                              itemExtent: _rowHeight,
                              proxyDecorator: (child, _, animation) => Material(
                                color: Colors.transparent,
                                elevation: 8 * animation.value,
                                borderRadius: BorderRadius.circular(20),
                                child: child,
                              ),
                              onReorderItem: (from, to) =>
                                  player.move(from, to),
                              itemBuilder: (context, i) => _QueueRow(
                                key: ValueKey('q$i-${queue[i].id}'),
                                onMenu: (at) => showTrackMenu(
                                  context,
                                  ref,
                                  at: at,
                                  tracks: picked.contains(i) ? [for (final k in (picked.toList()..sort())) queue[k]] : [queue[i]],
                                ),
                                picked: picked.contains(i),
                                index: i,
                                track: queue[i],
                                current: i == index,
                                playing: playing,
                                onPlay: () => tapped(i),
                                onRemove: () => player.removeAt(i),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.glyph,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final GlyphKind glyph;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        semanticLabel: tooltip,
        builder: (context, s) => AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.curve(context, Motion.spring),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary
                : (s.hovered
                      ? scheme.surfaceContainerHighest
                      : scheme.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(
              selected || s.pressed ? 14 : 22,
            ),
          ),
          child: Center(
            child: AnimatedGlyph(
              kind: glyph,
              size: 20,
              color: selected ? scheme.onPrimary : scheme.onSurface,
              active: s.pressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.onMenu,
    super.key,
    required this.index,
    required this.track,
    required this.current,
    required this.playing,
    required this.onPlay,
    required this.onRemove,
    required this.picked,
  });

  final bool picked;
  final int index;
  final Track track;
  final bool current;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  /// Right-click: the song menu at that spot.
  final void Function(Offset at) onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onPlay,
      semanticLabel:
          '${track.title}, ${track.artist}${current ? ', playing' : ''}${picked ? ', selected' : ''}',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.only(left: 6, right: 4),
        decoration: BoxDecoration(
          color: picked
              ? scheme.secondaryContainer
              : current
              ? scheme.primaryContainer.withValues(alpha: .6)
              : (s.hovered
                    ? scheme.surfaceContainerHighest
                    : scheme.surfaceContainerHighest.withValues(alpha: 0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(
                    alpha: s.hovered || current ? 1 : .45,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox.square(
              dimension: 44,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArt(
                      coverArt: track.coverArt,
                      seedKey: track.albumId,
                      resolution: 150,
                    ),
                    if (picked || current)
                      ColoredBox(
                        color: picked ? scheme.primary.withValues(alpha: .9) : scheme.scrim.withValues(alpha: .45),
                        child: Center(
                          child: picked ? Icon(Icons.check_rounded, size: 22, color: scheme.onPrimary) : MiniEq(
                            animating: playing,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NameText(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: current ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  NameText(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatDuration(track.duration),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Tooltip(
              message: 'Remove from queue',
              child: Pressable(
                onTap: onRemove,
                semanticLabel: 'Remove ${track.title} from queue',
                builder: (context, r) => SizedBox.square(
                  dimension: 36,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(
                      alpha: r.hovered || s.hovered ? 1 : 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown above the queue while rows are picked: how many, and take them out.
class _PickBar extends StatelessWidget {
  const _PickBar({required this.count, required this.onRemove, required this.onClear});

  final int count;
  final VoidCallback onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 1 ? '1 selected' : '$count selected',
              style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(tooltip: 'Remove from queue', onPressed: onRemove, icon: const Icon(Icons.playlist_remove_rounded)),
          IconButton(tooltip: 'Clear selection', onPressed: onClear, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}
