// Measures how smoothly the real rendering engine moves animated letters.
//
//   flutter run -d windows --profile -t tool/letter_probe_main.dart
//
// Each letter gets a distinct color so its pixels can be told apart even while
// letters overlap or fade. For every frame of a deterministic animation the
// probe captures the pixels, computes each letter's centroid and compares it
// with where the maths says it should be. Snapping or shimmer in the engine's
// text rendering shows up as jitter in that residual.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _text = 'ABCDEFGH';
const _fontSize = 58.0;
const _stagger = 18.0; // ms
const _per = 520.0; // ms
const _frameMs = 1000 / 60;

// Distinct color directions, one per letter.
const _palette = <(double, double, double)>[
  (1, 0, 0),
  (0, 1, 0),
  (0, 0, 1),
  (1, 1, 0),
  (0, 1, 1),
  (1, 0, 1),
  (1, .5, 0),
  (.5, 1, .5),
];

enum Variant {
  /// What the app does now: glyph alpha, rounded dy, rotation, plain Text at rest.
  current,

  /// Same without rounding dy to device pixels.
  noRounding,

  /// Never swap to a transform-free Text at rest (identity transform kept).
  keepTransform,

  /// Each letter in its own RepaintBoundary with Opacity + Transform layers.
  layered,
}

const _cubicSpring = Cubic(.34, 1.56, .64, 1);

/// Which direction the probe plays.
bool _exiting = false;

/// Exit uses its own (shorter) timing, like LetterSwap.
const _outStagger = 8.0;
const _outPer = 260.0;

double _pop(int i, double elapsedMs) {
  if (_exiting) {
    final t = ((elapsedMs - i * _outStagger) / _outPer).clamp(0.0, 1.0);
    return 1 - Curves.easeInCubic.transform(t);
  }
  final t = ((elapsedMs - i * _stagger) / _per).clamp(0.0, 1.0);
  return _cubicSpring.transform(t);
}

/// Glyph opacity for the same frame.
double _alpha(int i, double elapsedMs) {
  if (_exiting) {
    final t = ((elapsedMs - i * _outStagger) / _outPer).clamp(0.0, 1.0);
    return 1 - Curves.easeIn.transform(t);
  }
  return _pop(i, elapsedMs).clamp(0.0, 1.0);
}

class Probe extends StatefulWidget {
  const Probe({super.key});

  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  final _key = GlobalKey();
  Variant _variant = Variant.current;
  double _elapsed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final dpr = View.of(context).devicePixelRatio;
    stdout.writeln('devicePixelRatio=$dpr');
    for (final exiting in [false, true]) {
      _exiting = exiting;
      for (final v in Variant.values) {
        // The settled in-place render is the reference for every frame.
        setState(() {
          _variant = v;
          _elapsed = exiting ? -10000 : 10000;
        });
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        final rest = await _centroids(dpr);

        final total = exiting
            ? (_text.length - 1) * _outStagger + _outPer + 100
            : (_text.length - 1) * _stagger + _per + 200;
        final series = <List<({double x, double y})>>[];
        final expectedDy = <List<double>>[];
        final alphas = <List<double>>[];
        final frames = (total / _frameMs).ceil();
        for (var k = 0; k <= frames; k++) {
          setState(() => _elapsed = k * _frameMs);
          await WidgetsBinding.instance.endOfFrame;
          series.add(await _centroids(dpr));
          expectedDy.add([for (var i = 0; i < _text.length; i++) .65 * _fontSize * (1 - _pop(i, k * _frameMs))]);
          alphas.add([for (var i = 0; i < _text.length; i++) _alpha(i, k * _frameMs)]);
        }
        _report('${exiting ? 'exit ' : 'enter'} ${v.name}', rest, series, expectedDy, alphas);
      }
    }
    stdout.writeln('===== done =====');
    await stdout.flush();
    exit(0);
  }

  Future<List<({double x, double y})>> _centroids(double dpr) async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final w = image.width;
    final h = image.height;
    final sumX = List.filled(_text.length, 0.0);
    final sumY = List.filled(_text.length, 0.0);
    final weight = List.filled(_text.length, 0.0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        final r = data.getUint8(o).toDouble();
        final g = data.getUint8(o + 1).toDouble();
        final b = data.getUint8(o + 2).toDouble();
        final m = math.max(r, math.max(g, b));
        if (m < 12) continue;
        // Nearest palette direction.
        var best = 0;
        var bestD = double.infinity;
        for (var i = 0; i < _palette.length; i++) {
          final p = _palette[i];
          final pm = math.max(p.$1, math.max(p.$2, p.$3));
          final dr = r / m - p.$1 / pm;
          final dg = g / m - p.$2 / pm;
          final db = b / m - p.$3 / pm;
          final d = dr * dr + dg * dg + db * db;
          if (d < bestD) {
            bestD = d;
            best = i;
          }
        }
        weight[best] += m;
        sumX[best] += m * x;
        sumY[best] += m * y;
      }
    }
    image.dispose();
    return [
      for (var i = 0; i < _text.length; i++)
        weight[i] == 0 ? (x: double.nan, y: double.nan) : (x: sumX[i] / weight[i] / dpr, y: sumY[i] / weight[i] / dpr),
    ];
  }

  void _report(
    String name,
    List<({double x, double y})> rest,
    List<List<({double x, double y})>> series,
    List<List<double>> expectedDy,
    List<List<double>> alphas,
  ) {
    // Residual = measured y - (rest y + expected dy). Smooth rotation effects
    // are slow; snapping shows up as high-frequency change, so measure the
    // second difference of the residual, plus the jump onto the rest position.
    var worstSecond = 0.0;
    var sumSq = 0.0;
    var n = 0;
    var worstLanding = 0.0;
    var worstStepX = 0.0;
    for (var i = 0; i < _text.length; i++) {
      final res = <double>[];
      for (var k = 0; k < series.length; k++) {
        final c = series[k][i];
        // Very faint glyphs fall under the measurement threshold, which adds
        // noise that is not the engine's: ignore frames below 30 % alpha.
        if (c.y.isNaN || alphas[k][i] < .3) {
          res.add(double.nan);
          continue;
        }
        res.add(c.y - (rest[i].y + expectedDy[k][i]));
      }
      for (var k = 2; k < res.length; k++) {
        final a = res[k - 2];
        final b = res[k - 1];
        final c = res[k];
        if (a.isNaN || b.isNaN || c.isNaN) continue;
        final d2 = (c - 2 * b + a).abs();
        worstSecond = math.max(worstSecond, d2);
        sumSq += d2 * d2;
        n++;
      }
      // Landing: the last frames approach rest; how far is the final animated
      // frame from the settled render?
      final last = series.last[i];
      if (!last.y.isNaN) worstLanding = math.max(worstLanding, (last.y - rest[i].y).abs());
      for (var k = 1; k < series.length; k++) {
        final p = series[k - 1][i].x;
        final q = series[k][i].x;
        if (p.isNaN || q.isNaN) continue;
        // Horizontal motion is only the rotation wobble; steps should be tiny.
        worstStepX = math.max(worstStepX, (q - p).abs());
      }
    }
    final rms = n == 0 ? 0 : math.sqrt(sumSq / n);
    stdout.writeln('[$name] jitter rms=${rms.toStringAsFixed(3)}px  worst=${worstSecond.toStringAsFixed(3)}px   '
        'end-vs-rest=${worstLanding.toStringAsFixed(3)}px   worst x step=${worstStepX.toStringAsFixed(3)}px');
  }

  Widget _letters() {
    final dpr = View.of(context).devicePixelRatio;
    final children = <Widget>[];
    for (var i = 0; i < _text.length; i++) {
      final p = _pop(i, _elapsed);
      final pal = _palette[i];
      final alpha = p.clamp(0.0, 1.0);
      final base = Color.from(alpha: 1, red: pal.$1, green: pal.$2, blue: pal.$3);
      final style = TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w700, color: base, height: 1.1);
      final dyRaw = .65 * _fontSize * (1 - p);
      switch (_variant) {
        case Variant.current:
        case Variant.noRounding:
        case Variant.keepTransform:
          final glyph = Text(_text[i], style: style.copyWith(color: base.withValues(alpha: alpha)));
          final settled = (1 - p).abs() < .004 && alpha >= .999;
          if (settled && _variant != Variant.keepTransform) {
            children.add(glyph);
          } else {
            final dy = _variant == Variant.noRounding || _variant == Variant.keepTransform ? dyRaw : (dyRaw * dpr).round() / dpr;
            children.add(Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, dy, 0)..rotateZ(.1745 * (1 - p)),
              child: glyph,
            ));
          }
        case Variant.layered:
          children.add(Opacity(
            opacity: alpha,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, dyRaw, 0)..rotateZ(.1745 * (1 - p)),
              child: RepaintBoundary(child: Text(_text[i], style: style)),
            ),
          ));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
          child: RepaintBoundary(
            key: _key,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
              child: _letters(),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Probe());
}
