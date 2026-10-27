import '../../../app/perf_flags.dart';
import '../../../app/perf_stats.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OffsetLayer, RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/playback_providers.dart';
import '../../../app/theme/motion.dart';
import '../../../app/theme/settled_theme.dart';
import '../../../core/models/album.dart';
import '../../../core/models/artist.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/track.dart';
import '../../widgets/art_tile.dart';
import '../../widgets/cover_art.dart' show CoverImage, placeholderColors;
import '../../../app/providers/cover_providers.dart' show coverCacheProvider;
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
  const AlbumCard({
    super.key,
    required this.album,
    this.size,
    this.large = false,
  });

  final Album album;

  /// Cover edge length. Null fills the available width (grid cells).
  final double? size;

  /// Slightly bigger type used in the Library grid.
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAlbumIdProvider) == album.id;
    final playing =
        active && ref.watch(playbackProvider.select((s) => s.playing));
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
      onOpenSubtitle: album.artistId == null
          ? null
          : () => context.push('/artist/${album.artistId}'),
      drag: TrackDrag(
        label: album.title,
        load: () => ref.read(playbackProvider.notifier).albumTracks(album),
      ),
      onMenu: (at) => showCollectionMenu(
        context,
        ref,
        at: at,
        load: () => ref.read(playbackProvider.notifier).albumTracks(album),
        openLabel: 'Open album',
        openRoute: '/album/${album.id}',
        artistRoute: album.artistId == null
            ? null
            : '/artist/${album.artistId}',
      ),
    );
  }
}

/// An artist: round cover that springs into a scalloped shape on hover.
class ArtistCard extends ConsumerWidget {
  const ArtistCard({
    super.key,
    required this.artist,
    this.size,
    this.large = false,
  });

  final Artist artist;
  final double? size;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaCard(
      title: artist.name,
      subtitle: artist.albumCount == 1
          ? '1 album'
          : '${artist.albumCount} albums',
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
      drag: TrackDrag(
        label: artist.name,
        load: () => ref.read(playbackProvider.notifier).artistTracks(artist),
      ),
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
  const PlaylistCard({
    super.key,
    required this.playlist,
    this.size,
    this.large = false,
  });

  final Playlist playlist;
  final double? size;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaCard(
      title: playlist.name,
      subtitle: playlist.songCount == 1
          ? '1 song'
          : '${playlist.songCount} songs',
      coverArt: playlist.coverArt,
      seedKey: playlist.id,
      shape: ShapeKind.forKey(playlist.id),
      size: size,
      large: large,
      // Opens the playlist (its page has Play and Shuffle), like an artist.
      onTap: () => context.push('/playlist/${playlist.id}'),
      showPlay: false,
      onOpen: () => context.push('/playlist/${playlist.id}'),
      drag: TrackDrag(
        label: playlist.name,
        load: () =>
            ref.read(playbackProvider.notifier).playlistTracks(playlist),
      ),
      onMenu: (at) => showCollectionMenu(
        context,
        ref,
        at: at,
        load: () =>
            ref.read(playbackProvider.notifier).playlistTracks(playlist),
        openLabel: 'Open playlist',
        openRoute: '/playlist/${playlist.id}',
      ),
      acceptsDrop: () =>
          playlist.canEdit(ref.read(sessionProvider)?.username ?? ''),
      onDrop: (drag) async {
        final List<Track> tracks;
        try {
          tracks = await drag.load();
        } catch (_) {
          ref
              .read(toastProvider.notifier)
              .show('Couldn\'t get those songs from the server.', error: true);
          return;
        }
        if (context.mounted) {
          await addToExistingPlaylist(context, ref, playlist, tracks);
        }
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
  /// How many cards are built for the first time in one frame; the rest show a stand-in until
  /// the next frames (see `_BuildBudget`).
  static int firstBuildsPerFrame = 24;

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
  final _tileKey = GlobalKey();
  Offset _tilt = Offset.zero; // x: rotateY, y: rotateX (radians)

  // A resting card is drawn as one picture (see [_bake]): a hundred cards each made of a clip, a
  // shadow, a cover and two lines of text were most of the graphics thread's time while scrolling.
  final _boundaryKey = GlobalKey();
  ui.Image? _sprite;
  Size _spriteSize = Size.zero;
  Object? _spriteLook;
  Object? _look;
  bool _coverReady = false;
  bool _cardHover = false;
  bool _hoverMorph = false;
  Timer? _bakeTimer;

  /// Built as the real card at least once (see [_BuildBudget]).
  bool _full = false;

  /// What a card shows until its turn to be built: its placeholder colors in roughly its shape,
  /// and its title and subtitle as plain text, laid out at the same size as the real card.
  Widget _standIn(TextTheme text) {
    final (a, b) = placeholderColors(widget.seedKey);
    final standIn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, box) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
                borderRadius: BorderRadius.circular(widget.round ? box.maxWidth / 2 : box.maxWidth * .3),
              ),
            ),
          ),
        ),
        SizedBox(height: widget.large ? 14 : 12),
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(fontSize: widget.large ? 14.5 : 13, fontWeight: FontWeight.w700),
        ),
        Text(
          widget.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(fontSize: widget.large ? 12.5 : 12),
        ),
      ],
    );
    return widget.size != null ? SizedBox(width: widget.size, child: standIn) : standIn;
  }

  /// The picture reaches past the card by this much, for the shadow.
  static const _margin = 32.0;

  @override
  void initState() {
    super.initState();
    PerfStats.cardsBuilt++;
    PerfStats.liveCards++;
  }

  bool get _resting =>
      PerfFlags.instance.sprites &&
      !_cardHover &&
      !_hovered &&
      !_pressed &&
      !widget.active &&
      !_popMounted &&
      _tilt == Offset.zero;

  @override
  void didUpdateWidget(MediaCard old) {
    super.didUpdateWidget(old);
    if (old.coverArt != widget.coverArt) {
      _coverReady = false;
      _stopPreload();
    }
  }

  ImageStream? _coverStream;
  ImageStreamListener? _coverListener;
  CoverImage? _preloading;

  void _stopPreload() {
    if (_coverListener != null) _coverStream?.removeListener(_coverListener!);
    if (_preloading != null) CoverImage.letGo(_preloading!);
    _preloading = null;
    _coverStream = null;
    _coverListener = null;
  }

  void _preloadCover() {
    if (!mounted || _coverReady || _coverStream != null) return;
    final id = widget.coverArt;
    if (id == null) {
      setState(() => _coverReady = true);
      return;
    }
    final store = ProviderScope.containerOf(context, listen: false).read(coverCacheProvider);
    final image = CoverImage(store, id, 300);
    CoverImage.hold(image);
    final stream = image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void done() {
      stream.removeListener(listener);
      CoverImage.letGo(image);
      _preloading = null;
      _coverStream = null;
      _coverListener = null;
      // (Can be called at once, from inside this frame, when the cover is already in memory.)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_coverReady) setState(() => _coverReady = true);
      });
      SchedulerBinding.instance.scheduleFrame();
    }

    listener = ImageStreamListener((_, _) => done(), onError: (_, _) => done());
    _coverStream = stream;
    _coverListener = listener;
    _preloading = image;
    stream.addListener(listener);
  }

  void _dropSprite() {
    if (_sprite != null && PerfStats.enabled) {
      PerfStats.pictureCards--;
      PerfStats.liveCards++;
    }
    _sprite?.dispose();
    _sprite = null;
  }

  void _bake() {
    if (!mounted || !_resting || _sprite != null) return;
    final ro = _boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary || !ro.hasSize) return;
    // ignore: invalid_use_of_protected_member
    final layer = ro.layer;
    if (layer is! OffsetLayer) return;
    final size = ro.size;
    try {
      final clock = Stopwatch()..start();
      final image = layer.toImageSync(
        Rect.fromLTWH(-_margin, -_margin, size.width + 2 * _margin, size.height + 2 * _margin),
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      PerfStats.cardsBaked++;
      PerfStats.bakeMicros += clock.elapsedMicroseconds;
      PerfStats.pictureCards++;
      PerfStats.liveCards--;
      setState(() {
        _sprite = image;
        _spriteSize = size;
        _spriteLook = _look;
      });
    } catch (_) {
      PerfStats.bakesFailed++;
      // Not drawn yet, or no picture to be had: stay live.
    }
  }

  void _cardEnter() {
    if (_isScrolling || _cardHover) return;
    setState(() => _cardHover = true);
  }

  void _cardExit() {
    if (!_cardHover) return;
    setState(() => _cardHover = false);
  }

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
    if (_isScrolling && mounted) {
      if (_hovered) _leave();
      if (_cardHover) setState(() => _cardHover = false);
    }
  }

  void _enter() {
    setState(() {
      _hovered = true;
      _popGone?.cancel();
      _popMounted = true;
    });
    // The live card is built first as it rests, and springs into its hover shape a frame later
    // (built already hovered it would simply be there, with no spring).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hovered) {
        setState(() {
          _hoverMorph = true;
          _popOn = true;
        });
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
      _hoverMorph = false;
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
    if (_sprite != null) {
      PerfStats.pictureCards--;
    } else {
      PerfStats.liveCards--;
    }
    _stopPreload();
    _BakeQueue.remove(this);
    _bakeTimer?.cancel();
    _sprite?.dispose();
    _popGone?.cancel();
    _scrolling?.removeListener(_onScrolling);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PerfFlags.instance,
      builder: (context, _) => PerfFlags.instance.cards
          ? _buildCard(context)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCard(BuildContext context) {
    // The settled colors: a recolor redraws the card once, not on every frame of it.
    final theme = SettledTheme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    if (!_full) {
      if (!_BuildBudget.take()) {
        // Over this frame's budget: a stand-in now, the real card in a frame or two.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        PerfStats.standIns++;
        return _standIn(text);
      }
      _full = true;
    }
    PerfStats.cardBuilds++;
    final active = widget.active;
    final reduced = Motion.reduced(context);
    final morphed = _hoverMorph || active;

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
              tween: _PoseTween(
                end: _Pose(
                  tilt: reduced ? Offset.zero : _tilt,
                  lift: _hoverMorph && !reduced ? -4 : 0,
                  scale: _pressed ? .94 : 1,
                ),
              ),
              duration: reduced
                  ? Duration.zero
                  : (_hoverMorph && !_pressed ? Motion.fast : Motion.medium),
              curve: reduced
                  ? Curves.linear
                  : (_hoverMorph && !_pressed ? Motion.standard : Motion.spring),
              builder: (context, pose, child) =>
                  pose.tilt == Offset.zero && pose.lift == 0 && pose.scale == 1
                  // At rest there is no transform at all (each was a layer of its own).
                  ? child!
                  : Transform(
                      alignment: Alignment.center,
                      // A plain 2D matrix while the card is not being tilted: a perspective one on every card
                      // at rest made the compositor treat each as a 3D layer, a hundred of them per screen.
                      transform: pose.tilt == Offset.zero
                          ? (Matrix4.identity()
                              ..translateByDouble(0, pose.lift, 0, 1)
                              ..scaleByDouble(pose.scale, pose.scale, 1, 1))
                          : (Matrix4.identity()
                              ..setEntry(3, 2, 1 / 520)
                              ..translateByDouble(0, pose.lift, 0, 1)
                              ..rotateX(pose.tilt.dy)
                              ..rotateY(pose.tilt.dx)
                              ..scaleByDouble(pose.scale, pose.scale, 1, 1)),
                      child: child,
                    ),
              child: KeyedSubtree(
                key: _tileKey,
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
                        spin: (active || _hoverMorph) && !reduced ? .72 : 0,
                        onSettled: () {
                          if (mounted && !_coverReady) setState(() => _coverReady = true);
                        },
                        child: Ripple(
                          color: scheme.onPrimary,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    if (active)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: EqBadge(animating: widget.playing),
                          ),
                        ),
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
          ),
        );
      },
    );

    // Right-click, drag and drop: around the tile, live or resting.
    Widget decorate(Widget tile) {
      if (widget.onMenu != null) {
        tile = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapUp: (d) => widget.onMenu!(d.globalPosition),
          child: tile,
        );
      }
      if (widget.drag != null) {
        tile = TrackDragSource(drag: widget.drag!, child: tile);
      }
      if (widget.onDrop != null) {
        tile = TrackDropTarget(
          radius: 30,
          onDrop: widget.onDrop!,
          accepts: widget.acceptsDrop,
          child: tile,
        );
      }
      return tile;
    }

    final look = Object.hash(
      widget.title,
      widget.subtitle,
      widget.coverArt,
      _coverReady,
      widget.active,
      widget.round,
      scheme.primary,
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );
    if (look != _look) {
      // The colors are moving (a new album recolors the app for most of a second): any
      // picture is out of date, and a new one waits until they have settled.
      _look = look;
      _bakeTimer?.cancel();
      _bakeTimer = null;
    }
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        decorate(cover),
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
          style: text.bodySmall?.copyWith(
            fontSize: widget.large ? 12.5 : 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    Widget visual = MouseRegion(
      onEnter: (_) => _cardEnter(),
      onExit: (_) => _cardExit(),
      child: RepaintBoundary(key: _boundaryKey, child: card),
    );
    final sprite = _sprite;
    if (sprite != null && _resting && _spriteLook == look) {
      // At rest: the whole card is one picture, and what answers the pointer is a plain box.
      // Any hover makes the real card again (a frame later), so nothing is lost.
      visual = LayoutBuilder(
        builder: (context, box) {
          if ((box.maxWidth - _spriteSize.width).abs() > .5) {
            // The window was resized: this picture no longer fits.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(_dropSprite);
            });
            return MouseRegion(
              onEnter: (_) => _cardEnter(),
              onExit: (_) => _cardExit(),
              child: RepaintBoundary(key: _boundaryKey, child: card),
            );
          }
          final w = _spriteSize.width;
          final h = _spriteSize.height;
          return MouseRegion(
            onEnter: (_) => _cardEnter(),
            onExit: (_) => _cardExit(),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -_margin,
                    top: -_margin,
                    width: w + 2 * _margin,
                    height: h + 2 * _margin,
                    child: IgnorePointer(
                      child: RawImage(image: sprite, fit: BoxFit.fill, filterQuality: FilterQuality.low),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    width: w,
                    height: w,
                    child: decorate(
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onTap,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (_sprite != null) {
      // Out of date (or in use): the old picture goes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sprite != null && !(_resting && _spriteLook == _look)) {
          setState(_dropSprite);
        }
      });
    }
    if (_sprite != null && !_coverReady && _coverStream == null) {
      // Pictured while its cover was still on its way: keep fetching it, and draw the card
      // again (with its cover) once it is in.
      WidgetsBinding.instance.addPostFrameCallback((_) => _preloadCover());
    }
    if (_resting && _sprite == null) {
      _bakeTimer ??= Timer(const Duration(milliseconds: 150), () {
        _bakeTimer = null;
        _BakeQueue.add(this);
      });
    } else if (!_resting) {
      _bakeTimer?.cancel();
      _bakeTimer = null;
    }
    // One node for the whole card, with its other doings as named actions: the cover, the
    // title and the artist are not three or four separate things to a screen reader (and the
    // tilt and lift animate a transform that would otherwise update the tree on every frame).
    final node = Semantics(
      container: true,
      button: true,
      label:
          '${widget.title}, ${widget.subtitle}${widget.active ? ', playing' : ''}',
      onTap: widget.onTap,
      customSemanticsActions: {
        if (widget.onOpen != null)
          const CustomSemanticsAction(label: 'Open'): widget.onOpen!,
        if (widget.onOpenSubtitle != null)
          CustomSemanticsAction(label: 'Go to ${widget.subtitle}'):
              widget.onOpenSubtitle!,
        if (widget.onMenu != null)
          const CustomSemanticsAction(label: 'More options'): () {
            final box = context.findRenderObject()! as RenderBox;
            widget.onMenu!(box.localToGlobal(box.size.center(Offset.zero)));
          },
      },
      excludeSemantics: true,
      child: visual,
    );
    return widget.size != null
        ? SizedBox(width: widget.size, child: node)
        : node;
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
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: .35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 24,
                color: scheme.onPrimary,
              ),
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
  const TrackCard({
    super.key,
    required this.tracks,
    required this.index,
    this.size,
    this.large = false,
  });

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
      onTap: () =>
          ref.read(playbackProvider.notifier).playTracks(tracks, index: index),
      drag: TrackDrag.tracks([track]),
      onMenu: (at) => showTrackMenu(context, ref, at: at, tracks: [track]),
    );
  }
}

/// Cards waiting to be drawn into their picture, a few per frame: drawing a screenful of
/// pictures in one frame was a hitch of its own.
/// How many cards may be built for the first time in one frame. A card is about a third of a
/// millisecond to build; a letter jump or a trackpad fling replaced the whole screen (200+
/// cards) in one frame, 50-90 ms of building and then as long again drawing them. Past the
/// budget a card shows a stand-in and is built in the next frames, top to bottom. Ordinary
/// scrolling brings in fewer cards than this per frame and never sees a stand-in.
class _BuildBudget {
  static int get perFrame => MediaCard.firstBuildsPerFrame;
  static Duration? _frame;
  static int _left = 0;

  static bool take() {
    if (!PerfFlags.instance.cardBudget) return true;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (now != _frame) {
      _frame = now;
      _left = perFrame;
    }
    if (_left <= 0) return false;
    _left--;
    return true;
  }
}

class _BakeQueue {
  static const perFrame = 6;
  static final _waiting = <_MediaCardState>{};
  static bool _scheduled = false;

  static void add(_MediaCardState card) {
    _waiting.add(card);
    _schedule();
  }

  static void remove(_MediaCardState card) => _waiting.remove(card);

  static void _schedule() {
    if (_scheduled || _waiting.isEmpty) return;
    _scheduled = true;
    // After the next frame has been drawn (each card's layer must be painted to be copied).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      var done = 0;
      while (done < perFrame && _waiting.isNotEmpty) {
        final card = _waiting.first;
        _waiting.remove(card);
        if (!card.mounted) continue;
        card._bake();
        done++;
      }
      _schedule();
    });
    SchedulerBinding.instance.scheduleFrame();
  }
}
