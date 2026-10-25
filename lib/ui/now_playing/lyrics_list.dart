import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/lyrics_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/lyrics/lyrics.dart';
import 'lyrics_motion.dart';

export 'lyrics_motion.dart' show LyricsStyle;

/// A single scrolling list of every lyric line, ported closely from the demo's
/// `.ll` / `.il` CSS.
///
/// The active line is large, accent colored and kept at a fixed anchor by
/// translating the whole list (900 ms, emphasized); other lines dim, shrink and
/// blur with distance. Each property has its own CSS transition (opacity and
/// blur 800 ms, scale 900 ms, color 600 ms `ease`) that, when retargeted
/// mid-flight, continues from the value currently shown. Lines never leave the
/// list, they only animate.
///
/// Like the title letters, each line is baked into a texture once and then
/// scaled/faded/slid as an image, so moving text doesn't shimmer. Unsynced
/// lyrics are a plain scrollable list with no highlight.
class LyricsList extends ConsumerStatefulWidget {
  const LyricsList({super.key, required this.style, this.layoutWidth});

  final LyricsStyle style;

  /// Width lines wrap at (before scaling). Defaults to the available width
  /// over the active scale so the enlarged line still fits.
  final double? layoutWidth;

  @override
  ConsumerState<LyricsList> createState() => _LyricsListState();
}

class _LineTex {
  _LineTex(this.size, this.image, this.top);

  /// Laid-out (unscaled) text size in logical px.
  final Size size;

  /// White text on transparent, baked at `dpr * activeScale`; null if empty.
  final ui.Image? image;

  /// Top of the line in the list (logical px, before the slide).
  final double top;
}

class _LineAnim {
  _LineAnim(LineTarget t)
      : opacity = CssTransition(t.opacity),
        blur = CssTransition(t.blur),
        scale = CssTransition(t.scale),
        accent = CssTransition(t.accent);

  final CssTransition opacity;
  final CssTransition blur;
  final CssTransition scale;
  final CssTransition accent;

  bool isActive(Duration now) =>
      opacity.isActive(now) || blur.isActive(now) || scale.isActive(now) || accent.isActive(now);
}

class _LyricsListState extends ConsumerState<LyricsList> with SingleTickerProviderStateMixin {
  final _clock = Stopwatch()..start();
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker((_) => _onTick());
  final _slide = CssTransition(0);

  List<_LineTex> _lines = const [];
  List<_LineAnim> _anims = const [];
  double _pad = 0;
  Object? _sheetKey;
  int _active = 0;
  bool _reduced = false;
  ValueNotifier<Duration>? _position;

  @override
  void initState() {
    super.initState();
    final position = ref.read(positionProvider);
    position.addListener(_onPosition);
    _position = position;
    final lyrics = ref.read(lyricsProvider);
    if (lyrics.synced) _active = lyrics.activeIndexAt(position.value);
  }

  @override
  void dispose() {
    _position?.removeListener(_onPosition);
    _ticker.dispose();
    _disposeImages();
    _frame.dispose();
    super.dispose();
  }

  void _disposeImages() {
    for (final l in _lines) {
      l.image?.dispose();
    }
  }

  void _onPosition() {
    final lyrics = ref.read(lyricsProvider);
    if (!lyrics.synced || _lines.isEmpty) return;
    final i = lyrics.activeIndexAt(_position!.value);
    if (i == _active) return;
    _active = i;
    _applyTargets(animate: true);
    // Repainting is driven by the ticker; rebuild only so the accessibility
    // value (the active line) follows. This happens once per line.
    setState(() {});
  }

  void _onTick() {
    _frame.value++;
    final now = _clock.elapsed;
    if (!_slide.isActive(now) && !_anims.any((a) => a.isActive(now))) _ticker.stop();
  }

  /// Sets every line's (and the list's) target for the current active line,
  /// either snapping (first layout) or starting the CSS transitions.
  void _applyTargets({required bool animate}) {
    if (_lines.isEmpty) return;
    final now = _clock.elapsed;
    final style = widget.style;
    final speed = animate && !_reduced;
    Duration d(Duration x) => speed ? x : Duration.zero;
    for (var i = 0; i < _lines.length; i++) {
      final t = lineTarget((i - _active).abs(), style);
      final a = _anims[i];
      if (!animate) {
        a.opacity.snap(t.opacity);
        a.blur.snap(t.blur);
        a.scale.snap(t.scale);
        a.accent.snap(t.accent);
      } else {
        a.opacity.retarget(t.opacity, now, d(LyricTiming.opacity), LyricTiming.emphasized);
        a.blur.retarget(t.blur, now, d(LyricTiming.blur), LyricTiming.emphasized);
        a.scale.retarget(t.scale, now, d(LyricTiming.scale), LyricTiming.emphasized);
        a.accent.retarget(t.accent, now, d(LyricTiming.color), LyricTiming.colorCurve);
      }
    }
    final active = _lines[_active.clamp(0, _lines.length - 1)];
    final target = listOffsetFor(lineTop: active.top, lineHeight: active.size.height, style: style);
    if (animate) {
      _slide.retarget(target, now, d(LyricTiming.slide), LyricTiming.emphasized);
    } else {
      _slide.snap(target);
    }
    if (animate && speed && !_ticker.isActive) _ticker.start();
    _frame.value++;
  }

  /// (Re)bakes the line textures when lyrics, width, style or pixel ratio change.
  void _ensureSheet(Lyrics lyrics, double width, double dpr, TextStyle textStyle) {
    final key = (identityHashCode(lyrics), width, dpr, textStyle.fontSize, textStyle.height, textStyle.fontFamily);
    if (_sheetKey == key) return;
    _sheetKey = key;
    _disposeImages();

    final st = widget.style;
    final mask = textStyle.copyWith(color: const Color(0xFFFFFFFF));
    final bake = dpr * st.activeScale;
    _pad = st.fontSize * .35; // room for overhangs and the blur spreading out
    final lines = <_LineTex>[];
    var top = 0.0;
    for (final line in lyrics.lines) {
      final tp = TextPainter(
        text: TextSpan(text: line.text.isEmpty ? ' ' : line.text, style: mask),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      ui.Image? image;
      if (line.text.trim().isNotEmpty) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(bake);
        tp.paint(canvas, Offset(_pad, _pad));
        final picture = recorder.endRecording();
        image = picture.toImageSync(((tp.width + _pad * 2) * bake).ceil(), ((tp.height + _pad * 2) * bake).ceil());
        picture.dispose();
      }
      lines.add(_LineTex(Size(tp.width, tp.height), image, top));
      top += tp.height + st.spacing;
      tp.dispose();
    }
    _lines = lines;
    _anims = [for (var i = 0; i < lines.length; i++) _LineAnim(lineTarget((i - _active).abs(), st))];
    _applyTargets(animate: false);
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider);
    final scheme = Theme.of(context).colorScheme;
    final st = widget.style;
    _reduced = Motion.reduced(context);
    if (lyrics.isEmpty) return const SizedBox.shrink();
    if (!lyrics.synced) return _PlainList(lyrics: lyrics, style: st);

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final base = Theme.of(context).textTheme.bodyLarge!;
    final textStyle = base.copyWith(fontSize: st.fontSize, fontWeight: FontWeight.w700, height: st.lineHeight);

    return LayoutBuilder(
      builder: (context, box) {
        final width = widget.layoutWidth ?? box.maxWidth / st.activeScale;
        _ensureSheet(lyrics, width, dpr, textStyle);
        final activeText = lyrics.lines[_active.clamp(0, lyrics.lines.length - 1)].text;
        return Semantics(
          label: 'Lyrics',
          value: activeText,
          child: ExcludeSemantics(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.onSurface.withValues(alpha: 0),
                  scheme.onSurface,
                  scheme.onSurface,
                  scheme.onSurface.withValues(alpha: 0),
                ],
                stops: [0, st.fade, 1 - st.fade, 1],
              ).createShader(r),
              child: ClipRect(
                child: CustomPaint(
                  size: Size(box.maxWidth, box.maxHeight),
                  painter: _LyricsPainter(
                    repaint: _frame,
                    clock: _clock,
                    lines: _lines,
                    anims: _anims,
                    slide: _slide,
                    pad: _pad,
                    dpr: dpr,
                    bakeScale: st.activeScale,
                    normal: scheme.onSurface,
                    accent: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LyricsPainter extends CustomPainter {
  _LyricsPainter({
    required Listenable repaint,
    required this.clock,
    required this.lines,
    required this.anims,
    required this.slide,
    required this.pad,
    required this.dpr,
    required this.bakeScale,
    required this.normal,
    required this.accent,
  }) : super(repaint: repaint);

  final Stopwatch clock;
  final List<_LineTex> lines;
  final List<_LineAnim> anims;
  final CssTransition slide;
  final double pad;
  final double dpr;
  final double bakeScale;
  final Color normal;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final now = clock.elapsed;
    final dy = slide.at(now);
    final k0 = 1 / (dpr * bakeScale); // sprite pixels -> logical px at scale 1
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final image = line.image;
      if (image == null) continue;
      final a = anims[i];
      final scale = a.scale.at(now);
      final opacity = a.opacity.at(now);
      final blur = a.blur.at(now);
      final accentT = a.accent.at(now);

      // Skip lines that are entirely outside the viewport (with blur margin).
      final h = line.size.height;
      final cy = line.top + dy + h / 2;
      final reach = h * scale / 2 + pad * scale + blur * 3 + 4;
      if (cy + reach < 0 || cy - reach > size.height) continue;

      // CSS: transform-origin left center, so scale about (0, line center).
      final k = k0 * scale;
      final ax = pad * dpr * bakeScale; // left edge of the text inside the sprite
      final ay = (pad + h / 2) * dpr * bakeScale; // its vertical center
      final transforms = Float32List.fromList([k, 0, 0 - k * ax, cy - k * ay]);
      final rect = Float32List.fromList([0, 0, image.width.toDouble(), image.height.toDouble()]);
      final color = Color.lerp(normal, accent, accentT)!.withValues(alpha: opacity.clamp(0.0, 1.0));
      final paint = Paint()..filterQuality = FilterQuality.medium;
      final sigma = blur * scale;
      if (sigma > .05) {
        paint.imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
      }
      canvas.drawRawAtlas(
        image,
        transforms,
        rect,
        Int32List.fromList([color.toARGB32()]),
        BlendMode.modulate,
        null,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LyricsPainter old) => true;
}

class _PlainList extends StatelessWidget {
  const _PlainList({required this.lyrics, required this.style});

  final Lyrics lyrics;
  final LyricsStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        for (final l in lyrics.lines)
          Padding(
            padding: EdgeInsets.only(bottom: math.max(8, style.spacing / 2)),
            child: Text(
              l.text,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: style.fontSize,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
            ),
          ),
      ],
    );
  }
}
