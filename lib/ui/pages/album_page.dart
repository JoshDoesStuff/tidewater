import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/destinations.dart';
import '../../app/providers/library_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/album.dart';
import '../../core/models/track.dart';
import '../shell/shell_keys.dart';
import '../widgets/art_tile.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/eq_bars.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/ripple.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/link_text.dart';
import '../widgets/heart_button.dart';
import '../widgets/pressable.dart';
import '../widgets/shapes/morph_path.dart';
import 'page_frame.dart';

/// Back to where we came from, or the Library when this page was opened
/// directly (there is nothing to pop).
void goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Destination.library.path);
  }
}

final _random = math.Random();

String _minutes(Duration d) {
  final m = d.inMinutes;
  if (m >= 60) return '${m ~/ 60} hr ${m % 60} min';
  return '$m min';
}

/// An album: cover, play and shuffle, and its tracks.
class AlbumPage extends ConsumerStatefulWidget {
  const AlbumPage({super.key, required this.albumId});

  final String albumId;

  @override
  ConsumerState<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends ConsumerState<AlbumPage> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(albumDetailProvider(widget.albumId));
    // Hearts the server already has show up right away.
    ref.listen(albumDetailProvider(widget.albumId), (_, next) {
      next.whenData((d) => ref.read(likedProvider.notifier).seed(d.tracks));
    });
    return PageFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.hasError && !detail.hasValue)
              ErrorPanel(error: detail.error!, onRetry: () => ref.invalidate(albumDetailProvider(widget.albumId)))
            else if (!detail.hasValue)
              const _AlbumSkeleton()
            else
              _AlbumBody(detail: detail.requireValue),
          ],
        ),
      ),
    );
  }
}

class _AlbumSkeleton extends StatelessWidget {
  const _AlbumSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SkeletonBox(width: 220, height: 220, radius: 56),
            const SizedBox(width: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 90, height: 12, radius: 6),
                const SizedBox(height: 14),
                const SkeletonBox(width: 320, height: 40, radius: 12),
                const SizedBox(height: 14),
                const SkeletonBox(width: 180, height: 18, radius: 9),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < 6; i++) ...[
          const SkeletonBox(height: 56, radius: 18),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _AlbumBody extends ConsumerWidget {
  const _AlbumBody({required this.detail});

  final AlbumDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = detail.album;
    final tracks = detail.tracks;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final player = ref.read(playbackProvider.notifier);
    final active = ref.watch(activeAlbumIdProvider) == album.id;
    final playing = active && ref.watch(playbackProvider.select((s) => s.playing));
    final total = tracks.fold<Duration>(Duration.zero, (a, t) => a + t.duration);
    final meta = [
      if (album.year != null) '${album.year}',
      if (album.genre != null) album.genre!,
    ].join(' · ');

    final cover = ArtTile(
      coverArt: album.coverArt,
      seedKey: album.id,
      resolution: 800,
      size: 220,
      params: ShapeKind.forKey(album.id).params,
      morph: active ? 1 : 0,
      spin: playing && !Motion.reduced(context) ? .5 : 0,
      shadowAlpha: .4,
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          meta.isEmpty ? 'ALBUM' : 'ALBUM · $meta'.toUpperCase(),
          style: text.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: scheme.primary),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: LetterReveal(text: album.title, style: text.displaySmall, delay: const Duration(milliseconds: 100)),
        ),
        const SizedBox(height: 6),
        LinkText(
          text: album.artist,
          style: text.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
          onTap: album.artistId == null ? null : () => context.push('/artist/${album.artistId}'),
        ),
        const SizedBox(height: 6),
        Text(
          '${tracks.length} song${tracks.length == 1 ? '' : 's'} · ${_minutes(total)}',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ExpressivePillButton(
              label: playing ? 'Pause' : (active ? 'Resume' : 'Play'),
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onPressed: () => active ? player.toggle() : player.playTracks(tracks),
            ),
            ExpressivePillButton(
              label: 'Shuffle',
              icon: Icons.shuffle_rounded,
              glyph: GlyphKind.shuffle,
              filled: false,
              onPressed: () => player.playTracks(tracks, shuffle: true, index: tracks.isEmpty ? 0 : _random.nextInt(tracks.length)),
            ),
          ],
        ),
      ],
    );

    final discs = {for (final t in tracks) t.discNumber ?? 1};
    final rows = <Widget>[];
    int? lastDisc;
    for (final (i, t) in tracks.indexed) {
      final disc = t.discNumber ?? 1;
      if (discs.length > 1 && disc != lastDisc) {
        rows.add(Padding(
          padding: EdgeInsets.fromLTRB(20, lastDisc == null ? 8 : 18, 20, 6),
          child: Text(
            'Disc $disc',
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1, color: scheme.onSurfaceVariant),
          ),
        ));
      }
      lastDisc = disc;
      rows.add(_TrackRow(
        track: t,
        albumArtist: album.artist,
        number: t.trackNumber ?? i + 1,
        onPlay: () => player.playTracks(tracks, index: i),
      ));
    }

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [cover, const SizedBox(width: 32), Expanded(child: info)],
              )
            else ...[
              Center(child: cover),
              const SizedBox(height: 20),
              info,
            ],
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(32)),
              child: Column(children: rows),
            ),
          ],
        );
      },
    );
  }
}

class _TrackRow extends ConsumerWidget {
  const _TrackRow({required this.track, required this.albumArtist, required this.number, required this.onPlay});

  final Track track;
  final String albumArtist;
  final int number;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = ref.watch(currentTrackIdProvider) == track.id;
    final playing = current && ref.watch(playbackProvider.select((s) => s.playing));
    final liked = ref.watch(likedProvider.select((s) => s.contains(track.id)));
    final player = ref.read(playbackProvider.notifier);
    return Pressable(
      onTap: () => current ? player.toggle() : onPlay(),
      semanticLabel: '${track.title}, ${formatDuration(track.duration)}${current ? ', playing' : ''}',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        height: 56,
        padding: const EdgeInsets.only(left: 8, right: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: current
              ? scheme.primaryContainer.withValues(alpha: .55)
              : (s.hovered ? scheme.surfaceContainerHigh : scheme.surfaceContainerHigh.withValues(alpha: 0)),
          borderRadius: BorderRadius.circular(s.pressed ? 14 : 24),
        ),
        child: Ripple(
          color: scheme.onSurface,
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Center(
                  child: current
                      ? MiniEq(animating: playing, color: scheme.primary)
                      : (s.hovered
                          ? Icon(Icons.play_arrow_rounded, size: 22, color: scheme.onSurface)
                          : Text('$number', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: current ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    if (track.artist != albumArtist)
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              _HeartButton(
                liked: liked,
                visible: liked || s.hovered || current,
                onTap: () => ref.read(likedProvider.notifier).toggle(track),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  formatDuration(track.duration),
                  textAlign: TextAlign.right,
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              _RowMenu(track: track),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.liked, required this.visible, required this.onTap});

  final bool liked;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Motion.of(context, Motion.fast),
        child: HeartButton(liked: liked, onTap: onTap),
      );
}

class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final player = ref.read(playbackProvider.notifier);
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_vert_rounded, size: 22, color: scheme.onSurfaceVariant),
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Without a clip the hover highlight of the first and last item pokes out
      // past the rounded corners.
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black38,
      onSelected: (v) {
        switch (v) {
          case 'next':
            player.addNext([track]);
          case 'queue':
            player.addLast([track]);
          case 'artist':
            context.push('/artist/${track.artistId}');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'next', child: Text('Play next')),
        const PopupMenuItem(value: 'queue', child: Text('Add to queue')),
        if (track.artistId != null) const PopupMenuItem(value: 'artist', child: Text('Go to artist')),
      ],
    );
  }
}
