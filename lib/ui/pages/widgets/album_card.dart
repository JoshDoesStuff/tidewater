import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/playback_providers.dart';
import '../../../app/theme/motion.dart';
import '../../../core/models/album.dart';
import '../../../core/models/artist.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/track.dart';
import '../../widgets/art_tile.dart';
import '../../widgets/effects/eq_bars.dart';
import '../../widgets/effects/ripple.dart';
import '../../widgets/link_text.dart';
import '../../widgets/shapes/morph_path.dart';
import '../../widgets/track_drag.dart';
import '../../widgets/track_menu.dart';
import '../../widgets/playlist_flow.dart';
import '../../../app/providers/session_providers.dart';
import '../../../app/providers/ui_providers.dart';

/// An album: squircle cover with title and artist underneath.
class AlbumCard extends ConsumerWidget {
  const AlbumCard({super.key, required this.album, this.size, this.large = false});

  final Album album;

  /// Cover edge length. Null fills the available width (grid cells).
  final double? size;

  /// Slightly bigger type used in the Library grid.
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAlbumIdProvider) == album.id;
    final playing = active && ref.watch(playbackProvider.select((s) => s.playing));
    return MediaCard(
      title: album.title,
      subtitle: album.artist,
      coverArt: album.coverArt,
      seedKey: album.id,
      shape: ShapeKind.forKey(album.id),
      active: active,
      playing: playing,
      size: size,
      large: large,
      onTap: () => ref.read(playbackProvider.notifier).playAlbum(album),
      onOpen: () => context.push('/album/${album.id}'),
      onOpenSubtitle: album.artistId == null ? null : () => context.push('/artist/${album.artistId}'),
      drag: TrackDrag(label: album.title, load: () => ref.read(playbackProvider.notifier).albumTracks(album)),
      onMenu: (at) => showCollectionMenu(
        context,
        ref,
        at: at,
        load: () => ref.read(playbackProvider.notifier).albumTracks(album),
        openLabel: 'Open album',
        openRoute: '/album/${album.id}',
        artistRoute: album.artistId == null ? null : '/artist/${album.artistId}',
      ),
    );
  }
}

/// An artist: round cover that springs into a scalloped shape on hover.
class ArtistCard extends ConsumerWidget {
  const ArtistCard({super.key, required this.artist, this.size, this.large = false});

  final Artist artist;
  final double? size;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaCard(
      title: artist.name,
      subtitle: artist.albumCount == 1 ? '1 album' : '${artist.albumCount} albums',
      coverArt: artist.coverArt,
      seedKey: artist.id,
      shape: ShapeKind.forKey(artist.id),
      round: true,
      size: size,
      large: large,
      // Opens the artist (starting a dozen albums on a tap was a surprise).
      onTap: () => context.push('/artist/${artist.id}'),
      showPlay: false,
      onOpen: () => context.push('/artist/${artist.id}'),
      drag: TrackDrag(label: artist.name, load: () => ref.read(playbackProvider.notifier).artistTracks(artist)),
      onMenu: (at) => showCollectionMenu(
        context,
        ref,
        at: at,
        load: () => ref.read(playbackProvider.notifier).artistTracks(artist),
        openLabel: 'Open artist',
        openRoute: '/artist/${artist.id}',
      ),
    );
  }
}

/// A playlist: squircle cover with its name and song count.
class PlaylistCard extends ConsumerWidget {
  const PlaylistCard({super.key, required this.playlist, this.size, this.large = false});

  final Playlist playlist;
  final double? size;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaCard(
      title: playlist.name,
      subtitle: playlist.songCount == 1 ? '1 song' : '${playlist.songCount} songs',
      coverArt: playlist.coverArt,
      seedKey: playlist.id,
      shape: ShapeKind.forKey(playlist.id),
      size: size,
      large: large,
      // Opens the playlist (its page has Play and Shuffle), like an artist.
      onTap: () => context.push('/playlist/${playlist.id}'),
      showPlay: false,
      onOpen: () => context.push('/playlist/${playlist.id}'),
      drag: TrackDrag(label: playlist.name, load: () => ref.read(playbackProvider.notifier).playlistTracks(playlist)),
      onMenu: (at) => showCollectionMenu(
        context,
        ref,
        at: at,
        load: () => ref.read(playbackProvider.notifier).playlistTracks(playlist),
        openLabel: 'Open playlist',
        openRoute: '/playlist/${playlist.id}',
      ),
      acceptsDrop: () => playlist.canEdit(ref.read(sessionProvider)?.username ?? ''),
      onDrop: (drag) async {
        final List<Track> tracks;
        try {
          tracks = await drag.load();
        } catch (_) {
          ref.read(toastProvider.notifier).show('Couldn\'t get those songs from the server.', error: true);
          return;
        }
        if (context.mounted) await addToExistingPlaylist(context, ref, playlist, tracks);
      },
    );
  }
}

/// Cover with title and subtitle underneath.
///
/// Hover lifts the card, morphs the tile into its scalloped [shape], pops in
/// a play button and tilts toward the cursor. Press scales it down. An
/// [active] card stays morphed, slowly spins and (while [playing]) shows the
/// EQ badge.
class MediaCard extends StatefulWidget {
  const MediaCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.coverArt,
    required this.seedKey,
    required this.shape,
    required this.onTap,
    this.active = false,
    this.playing = false,
    this.round = false,
    this.showPlay = true,
    this.size,
    this.large = false,
    this.onOpen,
    this.onOpenSubtitle,
    this.onMenu,
    this.drag,
    this.onDrop,
    this.acceptsDrop,
  });

  final String title;
  final String subtitle;
  final String? coverArt;
  final String seedKey;
  final ShapeKind shape;
  final VoidCallback onTap;
  final bool active;
  final bool playing;

  /// Circle at rest instead of a squircle (artists).
  final bool round;

  /// Show the hover play button (an artist card opens a page instead).
  final bool showPlay;
  final double? size;
  final bool large;

  /// Opens the album/artist page (tapping the title). Null: plain text.
  final VoidCallback? onOpen;

  /// Opens whatever the subtitle names (an album's artist).
  final VoidCallback? onOpenSubtitle;

  /// Right-click (or the more menu): where on screen it was asked.
  final void Function(Offset at)? onMenu;

  /// What picking this card up and dropping it carries.
  final TrackDrag? drag;

  /// Songs dropped on the card (a playlist takes them); [acceptsDrop] can say no.
  final void Function(TrackDrag drag)? onDrop;
  final bool Function()? acceptsDrop;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  static const _maxTiltDeg = 6.0;

  bool _hovered = false;
  bool _pressed = false;
  /// The hover play button is only built from the first hover until a moment after the pointer
  /// leaves: it is four animated widgets, and a big grid of cards each holding an invisible one
  /// was a lot of idle work.
  bool _popMounted = false;
  bool _popOn = false;
  Timer? _popGone;
  Offset _tilt = Offset.zero; // x: rotateY, y: rotateX (radians)

  /// Whether the page is scrolling under the pointer. Cards sliding past a still mouse would each
  /// spring into their hover shape (a blurred shadow, a spin, a tilt) one after another: a
  /// scrolled page is not a hovered one.
  ValueListenable<bool>? _scrolling;
  bool get _isScrolling => _scrolling?.value ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position.isScrollingNotifier;
    if (next != _scrolling) {
      _scrolling?.removeListener(_onScrolling);
      _scrolling = next?..addListener(_onScrolling);
    }
  }

  void _onScrolling() {
    if (_isScrolling && _hovered && mounted) _leave();
  }

  void _enter() {
    setState(() {
      _hovered = true;
      _popGone?.cancel();
      if (!_popMounted) {
        // Built hidden first, then shown a frame later, so there is a pop to animate.
        _popMounted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _hovered) setState(() => _popOn = true);
        });
      } else {
        _popOn = true;
      }
    });
  }

  void _leave() {
    setState(() {
      _popGone?.cancel();
      _popGone = Timer(Motion.slow + const Duration(milliseconds: 100), () {
        if (mounted && !_hovered) setState(() => _popMounted = false);
      });
      _hovered = false;
      _popOn = false;
      _pressed = false;
      _tilt = Offset.zero;
    });
  }

  void _onHover(PointerEvent e, Size size) {
    if (_isScrolling) return;
    if (!_hovered) {
      // Scrolling has stopped with the pointer resting on this card.
      _enter();
    }
    final px = (e.localPosition.dx / size.width - .5).clamp(-.5, .5);
    final py = (e.localPosition.dy / size.height - .5).clamp(-.5, .5);
    const k = _maxTiltDeg * 2 * 0.0174533; // ±.5 → ±6°
    setState(() => _tilt = Offset(px * k, -py * k));
  }

  @override
  void dispose() {
    _popGone?.cancel();
    _scrolling?.removeListener(_onScrolling);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final active = widget.active;
    final reduced = Motion.reduced(context);
    final morphed = _hovered || active;

    final cover = LayoutBuilder(
      builder: (context, box) {
        final tileSize = Size(box.maxWidth, box.maxWidth);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            if (!_isScrolling) _enter();
          },
          onExit: (_) => _leave(),
          onHover: (e) => _onHover(e, tileSize),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: TweenAnimationBuilder<_Pose>(
              tween: _PoseTween(end: _Pose(tilt: reduced ? Offset.zero : _tilt, lift: _hovered && !reduced ? -4 : 0, scale: _pressed ? .94 : 1)),
              duration: reduced ? Duration.zero : (_hovered && !_pressed ? Motion.fast : Motion.medium),
              curve: reduced ? Curves.linear : (_hovered && !_pressed ? Motion.standard : Motion.spring),
              builder: (context, pose, child) => Transform(
                alignment: Alignment.center,
                transform: (Matrix4.identity()
                  ..setEntry(3, 2, 1 / 520)
                  ..translateByDouble(0, pose.lift, 0, 1)
                  ..rotateX(pose.tilt.dy)
                  ..rotateY(pose.tilt.dx)
                  ..scaleByDouble(pose.scale, pose.scale, 1, 1)),
                child: child,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ArtTile(
                      coverArt: widget.coverArt,
                      seedKey: widget.seedKey,
                      params: widget.shape.params,
                      exponent: widget.round ? 2 : 4.2,
                      morph: morphed ? 1 : 0,
                      spin: (active || _hovered) && !reduced ? .72 : 0,
                      child: Ripple(color: scheme.onPrimary, child: const SizedBox.expand()),
                    ),
                  ),
                  if (active)
                    Positioned.fill(
                      child: IgnorePointer(child: Center(child: EqBadge(animating: widget.playing))),
                    ),
                  if (_popMounted && widget.showPlay)
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: _PlayPop(visible: _popOn && !active),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    Widget tile = cover;
    if (widget.onMenu != null) {
      tile = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (d) => widget.onMenu!(d.globalPosition),
        child: tile,
      );
    }
    if (widget.drag != null) tile = TrackDragSource(drag: widget.drag!, child: tile);
    if (widget.onDrop != null) tile = TrackDropTarget(radius: 30, onDrop: widget.onDrop!, accepts: widget.acceptsDrop, child: tile);

    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile,
        SizedBox(height: widget.large ? 14 : 12),
        LinkText(
          text: widget.title,
          onTap: widget.onOpen,
          style: text.bodyMedium?.copyWith(
            fontSize: widget.large ? 14.5 : 13,
            fontWeight: FontWeight.w700,
            color: active ? scheme.primary : scheme.onSurface,
          ),
        ),
        LinkText(
          text: widget.subtitle,
          onTap: widget.onOpenSubtitle,
          style: text.bodySmall?.copyWith(fontSize: widget.large ? 12.5 : 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
    // One node for the whole card, with its other doings as named actions: the cover, the
    // title and the artist are not three or four separate things to a screen reader (and the
    // tilt and lift animate a transform that would otherwise update the tree on every frame).
    final node = Semantics(
      container: true,
      button: true,
      label: '${widget.title}, ${widget.subtitle}${widget.active ? ', playing' : ''}',
      onTap: widget.onTap,
      customSemanticsActions: {
        if (widget.onOpen != null) const CustomSemanticsAction(label: 'Open'): widget.onOpen!,
        if (widget.onOpenSubtitle != null) CustomSemanticsAction(label: 'Go to ${widget.subtitle}'): widget.onOpenSubtitle!,
        if (widget.onMenu != null)
          const CustomSemanticsAction(label: 'More options'): () {
            final box = context.findRenderObject()! as RenderBox;
            widget.onMenu!(box.localToGlobal(box.size.center(Offset.zero)));
          },
      },
      excludeSemantics: true,
      child: card,
    );
    return widget.size != null ? SizedBox(width: widget.size, child: node) : node;
  }
}

/// Hover play button: pops in with scale + untilt on the spring curve and
/// squares off a little.
class _PlayPop extends StatelessWidget {
  const _PlayPop({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Springy entrance, quick exit, so moving between cards never leaves a
    // fading button behind.
    final d = Motion.of(context, visible ? Motion.slow : Motion.fast);
    final c = visible ? Motion.curve(context, Motion.spring) : Motion.standard;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Motion.of(context, visible ? Motion.medium : Motion.fast),
        child: AnimatedScale(
          scale: visible ? 1 : .3,
          duration: d,
          curve: c,
          child: AnimatedRotation(
            turns: visible ? 0 : -.111,
            duration: d,
            curve: c,
            child: AnimatedContainer(
              duration: d,
              curve: c,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(visible ? 16 : 23),
                boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Icon(Icons.play_arrow_rounded, size: 24, color: scheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pose {
  const _Pose({required this.tilt, required this.lift, required this.scale});

  final Offset tilt;
  final double lift;
  final double scale;
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({super.end});

  @override
  _Pose lerp(double t) {
    final a = begin ?? end!;
    final b = end!;
    return _Pose(
      tilt: Offset.lerp(a.tilt, b.tilt, t)!,
      lift: a.lift + (b.lift - a.lift) * t,
      scale: a.scale + (b.scale - a.scale) * t,
    );
  }
}

/// A song as a card (Liked songs). Tapping plays [tracks] from this one.
class TrackCard extends ConsumerWidget {
  const TrackCard({super.key, required this.tracks, required this.index, this.size, this.large = false});

  final List<Track> tracks;
  final int index;
  final double? size;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = tracks[index];
    final current = ref.watch(currentTrackIdProvider) == track.id;
    return MediaCard(
      title: track.title,
      subtitle: track.artist,
      coverArt: track.coverArt,
      seedKey: track.albumId,
      shape: ShapeKind.forKey(track.id),
      size: size,
      large: large,
      active: current,
      playing: current && ref.watch(playbackProvider.select((s) => s.playing)),
      onTap: () => ref.read(playbackProvider.notifier).playTracks(tracks, index: index),
      drag: TrackDrag.tracks([track]),
      onMenu: (at) => showTrackMenu(context, ref, at: at, tracks: [track]),
    );
  }
}
