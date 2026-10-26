import '../widgets/name_text.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/lyrics_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../../core/playback/play_queue.dart' show LoopMode;
import '../../app/theme/motion.dart';
import '../../core/models/track.dart';
import '../shell/shell_keys.dart';
import '../widgets/art_tile.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/particle_burst.dart';
import '../widgets/effects/ripple.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/link_text.dart';
import '../widgets/pressable.dart';
import '../widgets/shapes/morph_path.dart';
import '../widgets/shapes/morph_shape.dart';
import '../widgets/wavy_progress.dart';
import 'lyrics_list.dart';
import 'queue_panel.dart';
import 'viz_picker.dart';
import 'visualizer/visualizer.dart';
import 'volume_slider.dart';

/// Cover bounds inside Now Playing (hero flight target, Ring visualizer origin).
final npCoverKey = GlobalKey(debugLabel: 'npCover');

const _designW = 1280.0;
const _designH = 800.0;

/// Width of the queue when docked beside the player.
const _dockWidth = 420.0;
const _idleAfter = Duration(milliseconds: 3500);
const _idleTick = Duration(milliseconds: 250);

class _Flight {
  const _Flight(this.delta, this.ratio);

  /// Offset of the mini cover from the Now Playing cover, in design pixels.
  final Offset delta;

  /// Mini cover size over Now Playing cover size.
  final double ratio;
}

/// Fullscreen Now Playing, laid out on a 1280x800 design canvas that is
/// scaled to fit the window (backdrop and visualizer fill the real window).
///
/// Opens with a FLIP-style flight of the cover from the mini player while the
/// other elements rise with a 70 ms stagger. After 3.5 s without input while
/// playing it goes idle: controls fade away, the cover glides, big lyrics (or
/// a centered caption) appear and a wavy progress runs along the bottom edge.
class NowPlayingOverlay extends ConsumerStatefulWidget {
  const NowPlayingOverlay({super.key});

  @override
  ConsumerState<NowPlayingOverlay> createState() => _NowPlayingOverlayState();
}

class _NowPlayingOverlayState extends ConsumerState<NowPlayingOverlay> with TickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 360),
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
    reverseDuration: const Duration(milliseconds: 360),
  );
  late final AnimationController _trackFx =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: 1);

  final _burstKey = GlobalKey<BurstLayerState>();
  final _heartKey = GlobalKey();

  bool _visible = false;
  Duration _sinceInput = Duration.zero; // counted in timer ticks
  Timer? _idleTimer;
  Timer? _swapTimer;
  _Flight? _flight;
  /// The track the screen shows. Lags the live track by the swap delay so the
  /// old text can animate out first.
  late Track? _shown = ref.read(currentTrackProvider);
  late int _kindIdx = _shown == null ? 0 : ShapeKind.forKey(_shown!.albumId).index;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _idleTimer?.cancel();
    _swapTimer?.cancel();
    _fade.dispose();
    _enter.dispose();
    _trackFx.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (_visible) _wake();
    return false;
  }

  void _wake() {
    _sinceInput = Duration.zero;
    if (ref.read(idleProvider)) ref.read(idleProvider.notifier).set(false);
  }

  void _open() {
    if (_visible) return;
    _sinceInput = Duration.zero;
    _flight = null;
    _fade.value = 0;
    _enter.value = 0;
    setState(() => _visible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureFlight();
      if (Motion.reduced(context)) {
        _fade.value = 1;
        _enter.value = 1;
      } else {
        _fade.forward();
        _enter.forward();
      }
    });
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(_idleTick, (_) => _checkIdle());
  }

  void _close() {
    if (!_visible) return;
    _idleTimer?.cancel();
    ref.read(idleProvider.notifier).set(false);
    ref.read(vizPopupOpenProvider.notifier).set(false);
    ref.read(queueOpenProvider.notifier).set(false);
    Future<void> done() async {
      if (!mounted || ref.read(nowPlayingOpenProvider)) return;
      setState(() => _visible = false);
    }

    if (Motion.reduced(context)) {
      _fade.value = 0;
      done();
    } else {
      // A snappier inverse of the open: the cover flies straight back to the mini
      // player (no hold, symmetrical ease) while everything else sinks away.
      _measureFlight();
      _enter.reverse(from: _enter.value);
      _fade.reverse(from: _fade.value).then((_) => done());
    }
  }

  void _checkIdle() {
    final state = ref.read(playbackProvider);
    // Not while waiting for the audio to start: the controls should stay in reach.
    final playing = state.playing && !state.buffering;
    final popup = ref.read(vizPopupOpenProvider) || ref.read(queueOpenProvider);
    _sinceInput += _idleTick;
    final should = playing && !popup && _sinceInput > _idleAfter;
    if (should != ref.read(idleProvider)) ref.read(idleProvider.notifier).set(should);
  }

  void _measureFlight() {
    final to = npCoverKey.currentContext?.findRenderObject() as RenderBox?;
    final from = miniCoverKey.currentContext?.findRenderObject() as RenderBox?;
    if (to == null || from == null || !to.attached || !from.attached) return;
    final toTL = to.localToGlobal(Offset.zero);
    final fromTL = from.localToGlobal(Offset.zero);
    final toW = to.localToGlobal(Offset(to.size.width, 0)).dx - toTL.dx;
    if (toW <= 0) return;
    final s = toW / to.size.width;
    _flight = _Flight((fromTL - toTL) / s, from.size.width / toW);
  }

  void _onTrack(Track? track) {
    if (track == null) return;
    if (!_visible || Motion.reduced(context)) {
      setState(() {
        _shown = track;
        _kindIdx = ShapeKind.forKey(track.albumId).index;
      });
      return;
    }
    // The whole track-change choreography follows the title-swap speed
    // setting. Progress maths in _slideSwap/_cover is relative, so only the
    // controller length and the swap moment scale.
    final speed = ref.read(letterSpeedProvider);
    _trackFx.duration = Duration(milliseconds: (600 / speed).round());
    _trackFx.forward(from: 0);
    _swapTimer?.cancel();
    _swapTimer = Timer(Duration(milliseconds: (190 / speed).round()), () {
      if (!mounted) return;
      setState(() {
        _shown = track;
        _kindIdx = ShapeKind.forKey(track.albumId).index;
      });
    });
  }

  Rect? _ringRect() {
    final cover = npCoverKey.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (cover == null || me == null || !cover.attached || !me.attached) return null;
    final tl = me.globalToLocal(cover.localToGlobal(Offset.zero));
    final br = me.globalToLocal(cover.localToGlobal(cover.size.bottomRight(Offset.zero)));
    return Rect.fromPoints(tl, br);
  }

  /// Closes Now Playing and opens a page (the playing album or artist).
  void _goTo(BuildContext context, String location) {
    ref.read(nowPlayingOpenProvider.notifier).set(false);
    GoRouter.of(context).push(location);
  }

  void _toggleLike() {
    final shown = _shown;
    if (shown == null) return;
    final wasLiked = ref.read(likedProvider).contains(shown.id);
    ref.read(likedProvider.notifier).toggle(shown);
    if (!wasLiked) {
      final heart = _heartKey.currentContext?.findRenderObject() as RenderBox?;
      final layer = _burstKey.currentContext?.findRenderObject() as RenderBox?;
      if (heart != null && layer != null) {
        final c = layer.globalToLocal(heart.localToGlobal(heart.size.center(Offset.zero)));
        _burstKey.currentState?.burst(c);
      }
    }
  }

  // ---- animation helpers ---------------------------------------------------

  /// Rise-in with a 70 ms stagger per [index] (see "other elements rise").
  Widget _rise(int index, Widget child) {
    return AnimatedBuilder(
      animation: _enter,
      child: child,
      builder: (context, c) {
        final raw = ((_enter.value * 820 - (120 + 70 * index)) / 560).clamp(0.0, 1.0);
        final e = Motion.emphasized.transform(raw);
        return Opacity(opacity: e, child: Transform.translate(offset: Offset(0, 26 * (1 - e)), child: c));
      },
    );
  }

  /// Idle: fade plus a 14 px slide, never receiving input while hidden.
  Widget _idleFade(bool idle, Widget child) {
    final reduced = Motion.reduced(context);
    return IgnorePointer(
      ignoring: idle,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: idle ? 1 : 0),
        duration: reduced ? Duration.zero : Motion.slow,
        curve: Motion.emphasized,
        builder: (context, t, c) => Opacity(
          opacity: 1 - t,
          child: Transform.translate(offset: Offset(0, 14 * t), child: c),
        ),
        child: child,
      ),
    );
  }

  /// Track-change slide: out (up), in (from below). [i] staggers by 40 ms.
  Widget _slideSwap(int i, Widget child) {
    return AnimatedBuilder(
      animation: _trackFx,
      child: child,
      builder: (context, c) {
        final raw = ((_trackFx.value * 600 - i * 40) / 560).clamp(0.0, 1.0);
        if (raw >= 1) return c!;
        final v = Motion.emphasized.transform(raw);
        double opacity;
        double dy;
        if (v < .35) {
          final p = v / .35;
          opacity = 1 - p;
          dy = -10 * p;
        } else if (v < .45) {
          opacity = 0;
          dy = -10 + 24 * ((v - .35) / .1);
        } else {
          final p = (v - .45) / .55;
          opacity = p;
          dy = 14 * (1 - p);
        }
        return Opacity(opacity: opacity, child: Transform.translate(offset: Offset(0, dy), child: c));
      },
    );
  }

  bool _queueDocked(BuildContext context) =>
      ref.watch(queueSidePanelProvider) && MediaQuery.sizeOf(context).width >= 1000;

  /// Whether the lyrics button and card are shown. A track still loading its
  /// lyrics keeps whatever the last one decided, so skipping from a track with
  /// no lyrics to another one doesn't flash the button in and out; only a
  /// finished lookup changes it.
  bool _lyricsShown = false;

  bool _lyricsAvailable() {
    final state = ref.watch(lyricsStateProvider);
    if (!state.isLoading) _lyricsShown = state.value?.isEmpty == false;
    return _lyricsShown;
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen(nowPlayingOpenProvider, (p, open) => open ? _open() : _close());
    // Pausing brings the controls back at once, not at the next idle check.
    ref.listen(playbackProvider.select((s) => s.playing), (_, now) {
      if (!now && _visible) _wake();
    });
    ref.listen(currentTrackIdProvider, (p, id) => _onTrack(ref.read(currentTrackProvider)));
    if (!_visible) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final idle = ref.watch(idleProvider);
    final lyricsOn = ref.watch(lyricsOnProvider);
    // With nothing to show, idle mode lays out like lyrics-off (cover centered).
    final lyricsAvailable = _lyricsAvailable();
    final mode = ref.watch(vizModeProvider);
    // The queue docks beside the player when there is room (and it is asked
    // for); otherwise it floats over it.
    final docked = _queueDocked(context);
    final queueOpen = ref.watch(queueOpenProvider);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Motion.emphasized, reverseCurve: Curves.easeIn),
      child: MouseRegion(
        cursor: idle ? SystemMouseCursors.none : MouseCursor.defer,
        onHover: (_) => _wake(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _wake(),
          onPointerMove: (_) => _wake(),
          onPointerSignal: (_) => _wake(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: scheme.surface),
              CustomPaint(painter: _BackdropPainter(scheme.primaryContainer.withValues(alpha: .6))),
              Visualizer(mode: mode, ringRect: _ringRect),
              // The player makes room for the docked queue by shrinking.
              AnimatedPadding(
                duration: Motion.of(context, Motion.slow),
                curve: Motion.curve(context, Motion.emphasized),
                padding: EdgeInsets.only(right: docked && queueOpen ? _dockWidth + 40 : 0),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _designW,
                    height: _designH,
                    child: BurstLayer(
                      key: _burstKey,
                      color: scheme.primary,
                      child: _design(context, idle: idle, lyricsOn: lyricsOn, idleLyrics: lyricsOn && lyricsAvailable),
                    ),
                  ),
                ),
              ),
              if (docked) const Positioned(key: ValueKey('queue-dock'), right: 20, top: 20, bottom: 20, width: _dockWidth, child: QueuePanel(docked: true)),
              _idleProgress(context, idle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _design(BuildContext context, {required bool idle, required bool lyricsOn, required bool idleLyrics}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduced = Motion.reduced(context);
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final track = _shown ?? ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();
    final slow = Motion.of(context, Motion.slow);
    final glideLeft = idle && !idleLyrics ? 420.0 : 100.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Top bar.
        Positioned(
          left: 36,
          right: 48,
          top: 44,
          height: 56,
          child: _rise(1, _idleFade(idle, _topBar(context))),
        ),

        // Cover column (glides to center in idle without lyrics).
        AnimatedPositioned(
          duration: slow,
          curve: Motion.emphasized,
          left: glideLeft,
          top: 180,
          width: 440,
          height: 440,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -40,
                top: -40,
                width: 520,
                height: 520,
                child: IgnorePointer(
                  child: MorphShape(
                    params: const ShapeParams(lobes: 12, amp: .05, base: .97),
                    morph: 1,
                    squareBase: false,
                    shadow: false,
                    spin: reduced ? 0 : -.18,
                    child: ColoredBox(color: scheme.primaryContainer.withValues(alpha: .5)),
                  ),
                ),
              ),
              Positioned.fill(child: _cover(track, playing, reduced)),
            ],
          ),
        ),

        // Volume.
        Positioned(
          left: 128,
          top: 678,
          width: 360,
          child: _rise(2, _idleFade(idle, const VolumeSlider())),
        ),

        // Right column.
        Positioned(
          left: 620,
          top: 110,
          width: 580,
          height: 646,
          child: _rise(0, _idleFade(idle, _rightColumn(context, track, lyricsOn))),
        ),

        // Idle lyrics beside the cover.
        Positioned(
          left: 640,
          top: 180,
          width: 580,
          height: 440,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: idle && idleLyrics ? 1 : 0,
              duration: slow,
              curve: Motion.standard,
              child: AnimatedSlide(
                offset: idle && idleLyrics ? Offset.zero : const Offset(30 / 580, 0),
                duration: slow,
                curve: Motion.emphasized,
                child: const LyricsList(style: LyricsStyle.idle, layoutWidth: 440),
              ),
            ),
          ),
        ),

        // Idle caption under the cover (never any lyric text here).
        AnimatedPositioned(
          duration: slow,
          curve: Motion.emphasized,
          left: idleLyrics ? 100 : 0,
          width: idleLyrics ? 440 : _designW,
          top: 650,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: idle ? 1 : 0,
              duration: slow,
              curve: Motion.standard,
              child: Column(
                children: [
                  NameText(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -.5),
                  ),
                  NameText(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(fontSize: 20, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Visualizer style popup (outside tap closes it).
        if (ref.watch(vizPopupOpenProvider))
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => ref.read(vizPopupOpenProvider.notifier).set(false),
            ),
          ),
        // Queue as a popup (outside tap closes it).
        if (!_queueDocked(context) && ref.watch(queueOpenProvider))
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => ref.read(queueOpenProvider.notifier).set(false),
            ),
          ),
        if (!_queueDocked(context))
          const Positioned(key: ValueKey('queue-popup'), right: 36, top: 100, bottom: 36, width: 440, child: QueuePanel()),
        const Positioned(key: ValueKey('viz-picker'), right: 44, top: 112, child: VizPicker()),
      ],
    );
  }

  Widget _cover(Track track, bool playing, bool reduced) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _trackFx]),
      builder: (context, child) {
        // Hero flight: from the mini player cover to here.
        final closing = _enter.status == AnimationStatus.reverse;
        final e = closing
            ? Curves.easeInOutCubic.transform(_enter.value)
            : Motion.emphasized.transform((_enter.value * 820 / 640).clamp(0.0, 1.0));
        final f = _flight;
        final m = Matrix4.identity();
        if (f != null && e < 1) {
          m
            ..translateByDouble(f.delta.dx * (1 - e), f.delta.dy * (1 - e), 0, 1)
            ..scaleByDouble(f.ratio + (1 - f.ratio) * e, f.ratio + (1 - f.ratio) * e, 1, 1);
        }
        // Track change: scale down and fade, swap, spring back up.
        final raw = (_trackFx.value * 600 / 560).clamp(0.0, 1.0);
        var scale = 1.0;
        var opacity = 1.0;
        if (raw < 1) {
          if (raw < .5) {
            final p = raw / .5;
            scale = 1 - .1 * p;
            opacity = 1 - .6 * p;
          } else {
            final p = Motion.spring.transform((raw - .5) / .5);
            scale = .9 + .1 * p;
            opacity = .4 + .6 * ((raw - .5) / .5);
          }
        }
        return Transform(
          alignment: Alignment.topLeft,
          transform: m,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => setState(() => _kindIdx = (_kindIdx + 1) % 5),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: KeyedSubtree(
            key: npCoverKey,
            child: ArtTile(
              coverArt: track.coverArt,
              seedKey: track.albumId,
              resolution: 800,
              size: 440,
              params: ShapeKind.values[_kindIdx].params,
              morph: playing ? 1 : 0,
              spin: playing && !reduced ? .36 : 0,
              shadowAlpha: .45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(vizModeProvider);
    final popup = ref.watch(vizPopupOpenProvider);
    return Row(
      children: [
        ExpressiveIconButton(
          icon: Icons.close_fullscreen_rounded,
          glyph: glyphFor(GlyphKind.collapse, size: 24),
          size: 56,
          squareRadius: 18,
          tooltip: 'Close (Esc)',
          onPressed: () => ref.read(nowPlayingOpenProvider.notifier).set(false),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Now playing',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
        ExpressiveIconButton(
          icon: Icons.auto_awesome_rounded,
          glyph: glyphFor(GlyphKind.visualizer, size: 26),
          size: 56,
          squareRadius: 18,
          selected: mode != VizMode.off || popup,
          tooltip: 'Visualizer (V)',
          onPressed: () => ref.read(vizPopupOpenProvider.notifier).toggle(),
        ),
        const SizedBox(width: 16),
        ExpressiveIconButton(
          icon: Icons.queue_music_rounded,
          glyph: glyphFor(GlyphKind.queue, size: 26),
          size: 56,
          squareRadius: 18,
          selected: ref.watch(queueOpenProvider),
          tooltip: 'Queue (Q)',
          onPressed: () => ref.read(queueOpenProvider.notifier).toggle(),
        ),
      ],
    );
  }

  Widget _rightColumn(BuildContext context, Track track, bool lyricsOn) {
    // The lyrics button and card follow [_lyricsShown], which only changes once a lookup finishes.
    final hasLyrics = _lyricsShown;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final controller = ref.read(playbackProvider.notifier);
    final state = ref.watch(playbackProvider);
    final position = ref.watch(positionProvider);
    final lyrics = ref.watch(lyricsProvider);
    final liked = ref.watch(likedProvider).contains(track.id);
    final duration = track.duration;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _slideSwap(
          0,
          LinkText(
            text: 'ALBUM · ${track.albumTitle}'.toUpperCase(),
            onTap: track.albumId.isEmpty ? null : () => _goTo(context, '/album/${track.albumId}'),
            style: text.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // A fixed-height slot: a long title shrinks to fit inside it, so the rest
        // of the column never moves between short and long titles.
        SizedBox(
          width: 580,
          height: 62,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // Follows the live track (not the delayed one) so the old title
            // pops out as soon as the track changes, then the new one pops in.
            child: LetterSwap(
              text: ref.watch(currentTrackProvider)?.title ?? track.title,
              speed: ref.watch(letterSpeedProvider),
              style: text.displayMedium?.copyWith(
                fontSize: 58,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1.05,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _slideSwap(
          1,
          LinkText(
            text: track.artist,
            onTap: track.artistId == null ? null : () => _goTo(context, '/artist/${track.artistId}'),
            style: text.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 580,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (track.qualityLabel != null) _Tag(label: track.qualityLabel!),
              if (!lyrics.isEmpty) _Tag(label: lyrics.synced ? 'Synced lyrics' : 'Lyrics'),
              _HeartChip(key: _heartKey, liked: liked, onTap: _toggleLike),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SizedBox(
          width: 580,
          height: 40,
          child: WavyScrubber(amplitude: 4, breathe: 7, wavelength: 28, strokeWidth: 6),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 580,
          child: ValueListenableBuilder<Duration>(
            valueListenable: position,
            builder: (context, p, _) {
              final style = text.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(p), style: style),
                  Text('-${formatDuration(duration - p)}', style: style),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // Centered under the progress bar; the lyrics button grows in and out of
        // the row, so the other controls slide to stay centered.
        SizedBox(
          width: 580,
          height: 84,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExpressiveIconButton(
                icon: Icons.shuffle_rounded,
                glyph: glyphFor(GlyphKind.shuffle, size: 26),
                size: 56,
                squareRadius: 18,
                selected: state.shuffle,
                tooltip: 'Shuffle',
                onPressed: controller.toggleShuffle,
              ),
              const SizedBox(width: 12),
              _WideButton(icon: Icons.skip_previous_rounded, glyph: GlyphKind.previous, label: 'Previous (P)', onTap: controller.previous),
              const SizedBox(width: 12),
              _BigPlay(playing: state.playing, onTap: controller.toggle),
              const SizedBox(width: 12),
              _WideButton(icon: Icons.skip_next_rounded, glyph: GlyphKind.next, label: 'Next (N)', onTap: controller.next),
              const SizedBox(width: 12),
              ExpressiveIconButton(
                icon: state.repeat == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                glyph: glyphFor(state.repeat == LoopMode.one ? GlyphKind.repeatOne : GlyphKind.repeat, size: 26),
                size: 56,
                squareRadius: 18,
                selected: state.repeat != LoopMode.off,
                tooltip: switch (state.repeat) {
                  LoopMode.off => 'Repeat: off',
                  LoopMode.all => 'Repeat: all',
                  LoopMode.one => 'Repeat: this track',
                },
                onPressed: controller.toggleRepeat,
              ),
              _LyricsSlot(
                visible: hasLyrics,
                selected: lyricsOn,
                onTap: ref.read(lyricsOnProvider.notifier).toggle,
              ),
            ],
          ),
        ),
        _LyricsCard(visible: lyricsOn && hasLyrics),
      ],
    );
  }

  /// Wavy progress along the bottom edge of the window with elapsed and
  /// remaining time at the corners. Only in idle mode.
  Widget _idleProgress(BuildContext context, bool idle) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final position = ref.watch(positionProvider);
    final duration = (_shown ?? ref.watch(currentTrackProvider))?.duration ?? Duration.zero;
    final style = text.bodySmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 6,
      height: 62,
      child: IgnorePointer(
        ignoring: !idle,
        child: AnimatedOpacity(
          opacity: idle ? 1 : 0,
          duration: Motion.of(context, Motion.slow),
          curve: Motion.standard,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 40,
                child: WavyScrubber(amplitude: 5, wavelength: 30, strokeWidth: 5, padding: 16),
              ),
              Positioned(
                left: 20,
                top: 0,
                child: ValueListenableBuilder<Duration>(
                  valueListenable: position,
                  builder: (context, p, _) => Text(formatDuration(p), style: style),
                ),
              ),
              Positioned(
                right: 20,
                top: 0,
                child: ValueListenableBuilder<Duration>(
                  valueListenable: position,
                  builder: (context, p, _) => Text('-${formatDuration(duration - p)}', style: style),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.color);

  final Color color;

  /// Soft glow: ellipse 60% x 70% of the window at (24%, 48%).
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * .24, size.height * .48);
    canvas.scale(size.width * .6, size.height * .7);
    canvas.drawRect(
      const Rect.fromLTRB(-3, -3, 3, 3),
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.color != color;
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
      // widthFactor: hug the label instead of stretching across the row.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Heart chip: pops (1 → 1.45 → 1) and squares off when liked.
class _HeartChip extends StatefulWidget {
  const _HeartChip({super.key, required this.liked, required this.onTap});

  final bool liked;
  final VoidCallback onTap;

  @override
  State<_HeartChip> createState() => _HeartChipState();
}

class _HeartChipState extends State<_HeartChip> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      semanticLabel: widget.liked ? 'Unlike' : 'Like',
      onTap: () {
        if (!Motion.reduced(context)) _pop.forward(from: 0);
        widget.onTap();
      },
      builder: (context, s) => AnimatedBuilder(
        animation: _pop,
        builder: (context, child) {
          final t = _pop.value;
          final scale = 1 + .45 * math.sin(math.pi * Motion.spring.transform(t).clamp(0.0, 1.0)) * (1 - t * .0);
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.curve(context, Motion.spring),
          width: 44,
          height: 34,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.liked ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(widget.liked ? 10 : 17),
          ),
          child: Ripple(
            color: widget.liked ? scheme.onPrimary : scheme.primary,
            child: Center(
              child: Icon(
                widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: widget.liked ? scheme.onPrimary : scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({required this.icon, required this.glyph, required this.label, required this.onTap});

  final IconData icon;
  final GlyphKind glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, s) => AnimatedScale(
        scale: s.pressed ? .96 : 1,
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curve(context, Motion.spring),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.curve(context, Motion.spring),
          width: 96,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(s.pressed ? 20 : 32),
          ),
          child: Ripple(
            color: scheme.onSecondaryContainer,
            child: Center(
              child: AnimatedGlyph(kind: glyph, size: 26, color: scheme.onSecondaryContainer, active: s.pressed),
            ),
          ),
        ),
      ),
    );
  }
}

class _BigPlay extends StatelessWidget {
  const _BigPlay({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: playing ? 'Pause (Space)' : 'Play (Space)',
      builder: (context, s) => AnimatedScale(
        scale: s.pressed ? .94 : 1,
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curve(context, Motion.spring),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.slow),
          curve: Motion.curve(context, Motion.spring),
          width: 128,
          height: 80,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(playing || s.pressed ? 28 : 40),
            boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Ripple(
            color: scheme.onPrimary,
            child: Center(child: PlayPauseIcon(playing: playing, size: 34, color: scheme.onPrimary)),
          ),
        ),
      ),
    );
  }
}

/// Lyrics card. Collapses (height, fade, margin; slow, emphasized) when
/// lyrics are toggled off.
class _LyricsCard extends ConsumerWidget {
  const _LyricsCard({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.emphasized,
      builder: (context, f, child) => Padding(
        padding: EdgeInsets.only(top: 16 * f),
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: f,
            child: Opacity(
              opacity: f,
              // Collapsed (no lyrics, or switched off): nothing to click, read or tab to.
              child: ExcludeSemantics(excluding: !visible, child: IgnorePointer(ignoring: !visible, child: child)),
            ),
          ),
        ),
      ),
      child: Container(
        height: 190,
        width: 580,
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(36)),
        child: Stack(
          children: [
            Positioned(
              left: 32,
              top: 22,
              child: Text(
                'LYRICS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
            const Positioned(
              left: 32,
              right: 32,
              top: 46,
              height: 128,
              child: LyricsList(style: LyricsStyle.card),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lyrics button and the gap before it. It grows in (width, fade, a little
/// scale) when lyrics are available and folds away when they are not, so the
/// controls beside it slide over rather than jump.
class _LyricsSlot extends StatelessWidget {
  const _LyricsSlot({required this.visible, required this.selected, required this.onTap});

  final bool visible;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.curve(context, Motion.emphasized),
      builder: (context, f, _) {
        if (f <= 0) return const SizedBox.shrink();
        final e = f.clamp(0.0, 1.0);
        // No clip: the button fades and scales as the space opens, never cut off.
        return Align(
          alignment: Alignment.centerLeft,
          widthFactor: e,
          child: Opacity(
            opacity: e,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Transform.scale(
                scale: .6 + .4 * e,
                child: IgnorePointer(ignoring: !visible, child: _LyricsButton(selected: selected, onTap: onTap)),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The speech-bubble button; its icon plays once when the button first shows.
class _LyricsButton extends StatefulWidget {
  const _LyricsButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LyricsButton> createState() => _LyricsButtonState();
}

class _LyricsButtonState extends State<_LyricsButton> {
  bool _entering = false;

  @override
  void initState() {
    super.initState();
    // One rising edge for the glyph, so it plays as the button appears; it is
    // released again so later presses can play it too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entering = true);
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _entering = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpressiveIconButton(
      icon: Icons.lyrics_rounded,
      glyph: (context, color, hovered, pressed) =>
          AnimatedGlyph(kind: GlyphKind.lyrics, size: 26, color: color, active: pressed || _entering),
      size: 56,
      squareRadius: 18,
      selected: widget.selected,
      tooltip: 'Lyrics (L)',
      onPressed: widget.onTap,
    );
  }
}
