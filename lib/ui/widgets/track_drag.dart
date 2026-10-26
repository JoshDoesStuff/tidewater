import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';
import '../../core/models/track.dart';

/// Songs being dragged: a few already in hand (a row, the picked rows) or a
/// whole album, artist or playlist that is only fetched when it is dropped.
class TrackDrag {
  const TrackDrag({required this.label, required this.load});

  TrackDrag.tracks(List<Track> tracks)
      : label = tracks.length == 1 ? tracks.single.title : '${tracks.length} songs',
        load = (() async => tracks);

  /// What the little card under the pointer says.
  final String label;
  final Future<List<Track>> Function() load;
}

/// Makes [child] something to pick up and drop on a [TrackDropTarget]. A click
/// still clicks: dragging only starts once the pointer has moved a little.
class TrackDragSource extends StatelessWidget {
  const TrackDragSource({super.key, required this.drag, required this.child, this.enabled = true});

  final TrackDrag drag;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Draggable<TrackDrag>(
      data: drag,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragCard(label: drag.label),
      childWhenDragging: Opacity(opacity: .45, child: child),
      child: child,
    );
  }
}

class _DragCard extends StatelessWidget {
  const _DragCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(14, 10),
      child: Material(
        color: scheme.primaryContainer,
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_note_rounded, size: 18, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 13),
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

/// Lights up while songs are dragged over it, and hands them to [onDrop].
class TrackDropTarget extends StatelessWidget {
  const TrackDropTarget({
    super.key,
    required this.child,
    required this.onDrop,
    this.radius = 24,
    this.accepts,
  });

  final Widget child;
  final void Function(TrackDrag drag) onDrop;
  final double radius;

  /// Says no to some drops (a playlist you cannot change). Null: takes them all.
  final bool Function()? accepts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<TrackDrag>(
      onWillAcceptWithDetails: (_) => accepts?.call() ?? true,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, over, _) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: over.isEmpty ? Colors.transparent : scheme.primary.withValues(alpha: .14),
          border: Border.all(color: over.isEmpty ? Colors.transparent : scheme.primary, width: 2),
        ),
        child: child,
      ),
    );
  }
}
