// Private fields are set from named, public constructor parameters.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A line of text whose letters are animated as **textures**, the way a
/// browser animates `<span style="display:inline-block">` letters.
///
/// Every glyph is rasterized once (white, at device resolution) into one atlas
/// image. Each frame all letters are drawn in a single `drawRawAtlas` call:
/// each sprite gets its own rotation/translation and its own color (the tint
/// with the letter's opacity, applied by `BlendMode.modulate`). So moving,
/// rotating or fading a letter never re-draws its outline (which makes stems
/// shimmer), never needs an off-screen pass per glyph (which stalled the GPU
/// when the theme recolored), and recoloring never re-rasterizes.
///
/// Glyphs are positioned from the whole string's layout, so kerning is kept,
/// and at rest each sprite is aligned to the device pixel grid so the text is
/// as crisp as normal text.

/// Where one glyph lives in the atlas and in the layout.
class GlyphSprite {
  const GlyphSprite(this.box, this.src, this.anchor);

  /// Layout box of the glyph within the whole string (logical px).
  final Rect box;

  /// Rect of the glyph's image in the atlas (device px). Empty for whitespace.
  final Rect src;

  /// Pivot inside the sprite (device px): the center of the layout box, which
  /// is where CSS rotates an inline-block span.
  final Offset anchor;

  bool get isBlank => src.isEmpty;
}

/// All glyphs of one string in one style at one device pixel ratio.
class GlyphSheet {
  GlyphSheet._(this.size, this.sprites, this.atlas, this.pad, this.dpr);

  /// Size of the laid-out string.
  final Size size;
  final List<GlyphSprite> sprites;

  /// White glyphs on transparent, at device resolution.
  final ui.Image? atlas;

  /// Transparent margin (logical px) around each glyph so overhangs and
  /// anti-aliased edges are not cut off.
  final double pad;
  final double dpr;

  factory GlyphSheet.build({required String text, required TextStyle style, required double dpr}) {
    // White mask; the real color is applied when drawing.
    final base = style.copyWith(color: const Color(0xFFFFFFFF), decoration: TextDecoration.none);
    final whole = TextPainter(
      text: TextSpan(text: text, style: base),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final pad = (style.fontSize ?? 14) * .2;

    // Lay glyph images out on shelves no wider than this (GPU texture limits).
    const maxRowPx = 2048.0;
    final painters = <TextPainter?>[];
    final boxes = <Rect>[];
    final srcs = <Rect>[];
    var x = 0.0;
    var y = 0.0;
    var rowH = 0.0;
    var atlasW = 1.0;
    var offset = 0;
    for (final ch in text.characters) {
      final selection = TextSelection(baseOffset: offset, extentOffset: offset + ch.length);
      offset += ch.length;
      final found = whole.getBoxesForSelection(selection);
      if (found.isEmpty) {
        painters.add(null);
        boxes.add(Rect.zero);
        srcs.add(Rect.zero);
        continue;
      }
      final box = found.first.toRect();
      boxes.add(box);
      if (ch.trim().isEmpty) {
        painters.add(null);
        srcs.add(Rect.zero);
        continue;
      }
      final one = TextPainter(
        text: TextSpan(text: ch, style: base),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final w = ((one.width + pad * 2) * dpr).ceilToDouble();
      final h = ((one.height + pad * 2) * dpr).ceilToDouble();
      if (x + w > maxRowPx && x > 0) {
        y += rowH;
        x = 0;
        rowH = 0;
      }
      painters.add(one);
      srcs.add(Rect.fromLTWH(x, y, w, h));
      x += w;
      rowH = math.max(rowH, h);
      atlasW = math.max(atlasW, x);
    }
    final atlasH = math.max(1.0, y + rowH);

    ui.Image? atlas;
    if (painters.any((p) => p != null)) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(dpr);
      for (var i = 0; i < painters.length; i++) {
        final p = painters[i];
        if (p == null) continue;
        p.paint(canvas, Offset(srcs[i].left / dpr + pad, srcs[i].top / dpr + pad));
        p.dispose();
      }
      final picture = recorder.endRecording();
      atlas = picture.toImageSync(atlasW.ceil(), atlasH.ceil());
      picture.dispose();
    }

    final sprites = <GlyphSprite>[
      for (var i = 0; i < boxes.length; i++)
        GlyphSprite(
          boxes[i],
          srcs[i],
          Offset((pad + boxes[i].width / 2) * dpr, (pad + boxes[i].height / 2) * dpr),
        ),
    ];
    final size = whole.size;
    whole.dispose();
    return GlyphSheet._(size, sprites, atlas, pad, dpr);
  }

  void dispose() => atlas?.dispose();
}

/// How far in/out a letter is: [pop] 1 in place, 0 fully out (dropped .65em,
/// tilted 10°; may overshoot while a spring settles); [opacity] 0..1.
typedef LetterState = ({double pop, double opacity});

class GlyphRun extends StatefulWidget {
  const GlyphRun({
    super.key,
    required this.text,
    required this.style,
    required this.state,
    this.repaint,
  });

  final String text;
  final TextStyle? style;

  /// State of letter [i]; read at paint time.
  final LetterState Function(int i) state;

  /// Repaints when this notifies (the animation controller).
  final Listenable? repaint;

  @override
  State<GlyphRun> createState() => _GlyphRunState();
}

class _GlyphRunState extends State<GlyphRun> {
  GlyphSheet? _sheet;
  String? _sheetText;
  TextStyle? _sheetStyle;
  double? _sheetDpr;
  final _fit = FitScale();

  @override
  void dispose() {
    _sheet?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bake at the pixel ratio times any scale the ancestors apply (see [FitScale]).
    final dpr = MediaQuery.devicePixelRatioOf(context) * _fit.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fit.measure(context)) setState(() {});
    });
    final effective = DefaultTextStyle.of(context).style.merge(widget.style);
    final color = effective.color ?? Theme.of(context).colorScheme.onSurface;
    final maskStyle = effective.copyWith(color: const Color(0xFFFFFFFF));
    if (_sheet == null || _sheetText != widget.text || _sheetStyle != maskStyle || _sheetDpr != dpr) {
      _sheet?.dispose();
      _sheet = GlyphSheet.build(text: widget.text, style: effective, dpr: dpr);
      _sheetText = widget.text;
      _sheetStyle = maskStyle;
      _sheetDpr = dpr;
    }
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: GlyphRunLeaf(
          sheet: _sheet!,
          tint: color,
          emSize: effective.fontSize ?? 14,
          state: widget.state,
          repaint: widget.repaint,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
      ),
    );
  }
}

class GlyphRunLeaf extends LeafRenderObjectWidget {
  const GlyphRunLeaf({
    super.key,
    required this.sheet,
    required this.tint,
    required this.emSize,
    required this.state,
    required this.repaint,
    required this.devicePixelRatio,
  });

  /// The screen's pixel ratio (the sheet may be baked finer to match a scale above it).
  final double devicePixelRatio;
  final GlyphSheet sheet;
  final Color tint;
  final double emSize;
  final LetterState Function(int i) state;
  final Listenable? repaint;

  @override
  RenderGlyphRun createRenderObject(BuildContext context) =>
      RenderGlyphRun(
        sheet: sheet,
        tint: tint,
        emSize: emSize,
        state: state,
        repaint: repaint,
        devicePixelRatio: devicePixelRatio,
      );

  @override
  void updateRenderObject(BuildContext context, RenderGlyphRun renderObject) {
    renderObject
      ..sheet = sheet
      ..tint = tint
      ..emSize = emSize
      ..state = state
      ..repaint = repaint
      ..devicePixelRatio = devicePixelRatio;
  }
}

class RenderGlyphRun extends RenderBox {
  RenderGlyphRun({
    required GlyphSheet sheet,
    required Color tint,
    required double emSize,
    required LetterState Function(int i) state,
    required Listenable? repaint,
    required double devicePixelRatio,
  })  : _sheet = sheet,
        _devicePixelRatio = devicePixelRatio,
        _tint = tint,
        _emSize = emSize,
        _state = state,
        _repaint = repaint;

  GlyphSheet _sheet;
  double _devicePixelRatio;

  set devicePixelRatio(double v) {
    if (v == _devicePixelRatio) return;
    _devicePixelRatio = v;
    markNeedsPaint();
  }

  Color _tint;
  double _emSize;
  LetterState Function(int i) _state;
  Listenable? _repaint;

  /// The baked textures (exposed so tests can check their resolution).
  GlyphSheet get sheet => _sheet;

  set sheet(GlyphSheet v) {
    if (identical(v, _sheet)) return;
    _sheet = v;
    markNeedsLayout();
    markNeedsPaint();
  }

  set tint(Color v) {
    if (v == _tint) return;
    _tint = v;
    markNeedsPaint();
  }

  set emSize(double v) {
    if (v == _emSize) return;
    _emSize = v;
    markNeedsPaint();
  }

  set state(LetterState Function(int i) v) {
    _state = v;
    markNeedsPaint();
  }

  set repaint(Listenable? v) {
    if (identical(v, _repaint)) return;
    if (attached) _repaint?.removeListener(markNeedsPaint);
    _repaint = v;
    if (attached) _repaint?.addListener(markNeedsPaint);
  }

  /// Current opacity of every letter (for tests).
  @visibleForTesting
  List<double> debugOpacities() => [for (var i = 0; i < _sheet.sprites.length; i++) _state(i).opacity.clamp(0.0, 1.0)];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _sheet.size.width;

  @override
  double computeMaxIntrinsicWidth(double height) => _sheet.size.width;

  @override
  double computeMinIntrinsicHeight(double width) => _sheet.size.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _sheet.size.height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(_sheet.size);

  @override
  void performLayout() {
    size = constraints.constrain(_sheet.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final sheet = _sheet;
    final atlas = sheet.atlas;
    if (atlas == null) return;
    final dpr = sheet.dpr;

    // Pixel-align each glyph's resting position on the screen's pixel grid. That
    // works through any uniform scale above this (the player canvas fitted to
    // the window), but not through a rotation or a stretch.
    final m = getTransformTo(null);
    final k = m.entry(0, 0);
    final unscaled = k > 0 &&
        (m.entry(1, 1) - k).abs() < 1e-4 * k &&
        m.entry(0, 1).abs() < 1e-6 &&
        m.entry(1, 0).abs() < 1e-6;
    final originX = m.entry(0, 3);
    final originY = m.entry(1, 3);

    final n = sheet.sprites.length;
    final transforms = Float32List(n * 4);
    final rects = Float32List(n * 4);
    final colors = Int32List(n);
    var count = 0;
    final scale = 1 / dpr;
    for (var i = 0; i < n; i++) {
      final g = sheet.sprites[i];
      if (g.isBlank) continue;
      final s = _state(i);
      final alpha = s.opacity.clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      var snapX = 0.0;
      var snapY = 0.0;
      if (unscaled) {
        // Align the sprite's top-left (box minus its padding) to device pixels.
        // Global, in logical pixels; the device pixel is 1 / devicePixelRatio of it.
        final imageX = originX + k * (g.box.left - sheet.pad);
        final imageY = originY + k * (g.box.top - sheet.pad);
        final deviceX = imageX * _devicePixelRatio;
        final deviceY = imageY * _devicePixelRatio;
        // The correction is in this object's own units: global / k.
        snapX = (deviceX.round() - deviceX) / (_devicePixelRatio * k);
        snapY = (deviceY.round() - deviceY) / (_devicePixelRatio * k);
      }

      // CSS: rotate about the letter box's center, then translate.
      final dy = .65 * _emSize * (1 - s.pop);
      final rot = .1745 * (1 - s.pop);
      final cos = math.cos(rot) * scale;
      final sin = math.sin(rot) * scale;
      final px = offset.dx + g.box.center.dx + snapX;
      final py = offset.dy + g.box.center.dy + dy + snapY;
      final o = count * 4;
      transforms[o] = cos;
      transforms[o + 1] = sin;
      transforms[o + 2] = px - (cos * g.anchor.dx - sin * g.anchor.dy);
      transforms[o + 3] = py - (sin * g.anchor.dx + cos * g.anchor.dy);
      rects[o] = g.src.left;
      rects[o + 1] = g.src.top;
      rects[o + 2] = g.src.right;
      rects[o + 3] = g.src.bottom;
      colors[count] = _tint.withValues(alpha: _tint.a * alpha).toARGB32();
      count++;
    }
    if (count == 0) return;

    // One draw for all letters. modulate: sprite (white, alpha mask) x color.
    context.canvas.drawRawAtlas(
      atlas,
      count == n ? transforms : Float32List.sublistView(transforms, 0, count * 4),
      count == n ? rects : Float32List.sublistView(rects, 0, count * 4),
      count == n ? colors : Int32List.sublistView(colors, 0, count),
      BlendMode.modulate,
      null,
      Paint()..filterQuality = FilterQuality.low,
    );
  }
}

/// How much the widgets above one on screen scale it (a `FittedBox` shrinking or
/// growing the Now Playing canvas to the window). Text baked into a texture at
/// the screen's pixel ratio alone looks soft once such a scale stretches it
/// (a window dragged from a 200 % laptop panel to a 100 % monitor), so
/// textures are baked at pixel ratio times this.
class FitScale {
  FitScale({this.tolerance = .005});

  /// How far the scale may drift (as a fraction) before textures are baked again.
  final double tolerance;

  double value = 1;

  /// Re-reads the scale for [context]; true when it moved enough that textures
  /// should be baked again.
  bool measure(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final s = box.getTransformTo(null).getMaxScaleOnAxis();
    if (!s.isFinite || s <= 0) return false;
    if ((s - value).abs() > value * tolerance) {
      // Exactly the scale on screen, so the texture lands 1:1 on device pixels.
      value = s;
      return true;
    }
    return false;
  }
}
