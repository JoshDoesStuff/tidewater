// Measures how smoothly the real rendering engine moves animated letters.
//
//   flutter run -d windows --profile -t tool/letter_probe_main.dart
//
// Each letter gets a distinct color so its pixels can be told apart even while
// letters overlap or fade. For every frame of a deterministic animation the
// probe captures the pixels, computes each letter's centroid and compares it
// with where the EXACT curve says it should be (so a noisy easing function
// shows up too). It also reports how much the picture changes frame to frame
// over the last frames before the letters land: a smooth settle trends to 0,
// a pop shows as a spike.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tidewater/app/theme/precise_cubic.dart';

const _text = 'ABCDEFGH';
const _fontSize = 58.0;
const _stagger = 18.0; // ms
const _per = 520.0; // ms
const _outStagger = 8.0;
const _outPer = 260.0;
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
  /// Flutter's own Cubic (bisection, 0.001 tolerance).
  flutterCurve,

  /// PreciseCubic: exact, like CSS cubic-bezier. Swaps to plain Text at rest.
  preciseCurve,

  /// Exact curve; the Transform is kept at rest (identity matrix).
  preciseKeep,

  /// Exact curve; a tiny permanent tilt so the transform is never identity
  /// (the engine can never switch rendering path).
  preciseTilted,

  /// Exact curve; rotation dropped early so the tail is translation-only.
  preciseEarlySnap,
}

const _exactSpring = PreciseCubic(.34, 1.56, .64, 1);
const _exactExit = PreciseCubic(.55, .055, .675, .19);
const _exactFade = PreciseCubic(.42, 0, 1, 1);
const _flutterSpring = Cubic(.34, 1.56, .64, 1);
const _flutterExit = Cubic(.55, .055, .675, .19);
const _flutterFade = Cubic(.42, 0, 1, 1);

bool _exiting = false;

/// `pop` for letter [i]: 1 in place, 0 fully out. [exact] picks the curve.
double _pop(int i, double elapsedMs, {required bool exact}) {
  if (_exiting) {
    final t = ((elapsedMs - i * _outStagger) / _outPer).clamp(0.0, 1.0);
    return 1 - (exact ? _exactExit : _flutterExit).transform(t);
  }
  final t = ((elapsedMs - i * _stagger) / _per).clamp(0.0, 1.0);
  return (exact ? _exactSpring : _flutterSpring).transform(t);
}

double _alpha(int i, double elapsedMs, {required bool exact}) {
  if (_exiting) {
    final t = ((elapsedMs - i * _outStagger) / _outPer).clamp(0.0, 1.0);
    return 1 - (exact ? _exactFade : _flutterFade).transform(t);
  }
  return _pop(i, elapsedMs, exact: exact).clamp(0.0, 1.0);
}

class Probe extends StatefulWidget {
  const Probe({super.key});

  @override
  State<Probe> createState() => _ProbeState();
}

class _Capture {
  _Capture(this.centroids, this.pixels);
  final List<({double x, double y})> centroids;
  final Uint8List pixels;
}

class _ProbeState extends State<Probe> {
  final _key = GlobalKey();
  Variant _variant = Variant.flutterCurve;
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
        setState(() {
          _variant = v;
          _elapsed = exiting ? -10000 : 10000; // settled in-place reference
        });
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        final rest = await _capture(dpr);
        if (!exiting) {
          // Save the settled render so rest sharpness can be compared by eye.
          final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: dpr);
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          Directory('build/probe').createSync(recursive: true);
          File('build/probe/rest_${v.name}.png').writeAsBytesSync(png.buffer.asUint8List());
          image.dispose();
        }

        final total =
            exiting ? (_text.length - 1) * _outStagger + _outPer + 100 : (_text.length - 1) * _stagger + _per + 200;
        final frames = (total / _frameMs).ceil();
        final caps = <_Capture>[];
        final expectedDy = <List<double>>[];
        final alphas = <List<double>>[];
        for (var k = 0; k <= frames; k++) {
          setState(() => _elapsed = k * _frameMs);
          await WidgetsBinding.instance.endOfFrame;
          caps.add(await _capture(dpr));
          // Expected motion always comes from the EXACT curve.
          expectedDy.add([for (var i = 0; i < _text.length; i++) .65 * _fontSize * (1 - _pop(i, k * _frameMs, exact: true))]);
          alphas.add([for (var i = 0; i < _text.length; i++) _alpha(i, k * _frameMs, exact: true)]);
        }
        _report('${exiting ? 'exit ' : 'enter'} ${v.name}', rest, caps, expectedDy, alphas, exiting);
      }
    }
    stdout.writeln('===== done =====');
    await stdout.flush();
    exit(0);
  }

  Future<_Capture> _capture(double dpr) async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes = data.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    final sumX = List.filled(_text.length, 0.0);
    final sumY = List.filled(_text.length, 0.0);
    final weight = List.filled(_text.length, 0.0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        final r = bytes[o].toDouble();
        final g = bytes[o + 1].toDouble();
        final b = bytes[o + 2].toDouble();
        final m = math.max(r, math.max(g, b));
        if (m < 12) continue;
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
    return _Capture([
      for (var i = 0; i < _text.length; i++)
        weight[i] == 0 ? (x: double.nan, y: double.nan) : (x: sumX[i] / weight[i] / dpr, y: sumY[i] / weight[i] / dpr),
    ], Uint8List.fromList(bytes));
  }

  void _report(
    String name,
    _Capture rest,
    List<_Capture> caps,
    List<List<double>> expectedDy,
    List<List<double>> alphas,
    bool exiting,
  ) {
    // Jitter: second difference of (measured y - expected y). Rotation effects
    // are slow; snapping or a noisy curve is high-frequency.
    var worstSecond = 0.0;
    var sumSq = 0.0;
    var n = 0;
    for (var i = 0; i < _text.length; i++) {
      final res = <double>[];
      for (var k = 0; k < caps.length; k++) {
        final c = caps[k].centroids[i];
        if (c.y.isNaN || alphas[k][i] < .3) {
          res.add(double.nan);
          continue;
        }
        res.add(c.y - (rest.centroids[i].y + expectedDy[k][i]));
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
    }
    final rms = n == 0 ? 0 : math.sqrt(sumSq / n);

    // Landing: summed absolute pixel change between consecutive frames, over
    // the last frames. Entering: letters settle to rest, so changes should
    // shrink toward 0 with no spike at the end.
    final diffs = <double>[];
    for (var k = 1; k < caps.length; k++) {
      var s = 0;
      final a = caps[k - 1].pixels;
      final b = caps[k].pixels;
      for (var o = 0; o < a.length; o++) {
        s += (a[o] - b[o]).abs();
      }
      diffs.add(s / 1000);
    }
    // Last nonzero diff: the frame where the picture last changed.
    var lastChange = diffs.length - 1;
    while (lastChange > 0 && diffs[lastChange] == 0) {
      lastChange--;
    }
    final lastDiff = diffs[lastChange];
    final before = lastChange > 0 ? diffs[lastChange - 1] : 0.0;
    // First change (exit starts from rest: the mirror-image problem).
    var firstChange = 0;
    while (firstChange < diffs.length - 1 && diffs[firstChange] == 0) {
      firstChange++;
    }
    final firstDiff = diffs[firstChange];
    final after = firstChange + 1 < diffs.length ? diffs[firstChange + 1] : 0.0;
    final edge = exiting
        ? 'start: first change ${firstDiff.toStringAsFixed(1)} then ${after.toStringAsFixed(1)}'
        : 'landing: last change ${lastDiff.toStringAsFixed(1)} after ${before.toStringAsFixed(1)} '
            '(spike x${before == 0 ? 0 : (lastDiff / before).toStringAsFixed(1)})';
    stdout.writeln('[$name] jitter rms=${rms.toStringAsFixed(3)}px worst=${worstSecond.toStringAsFixed(3)}px | $edge');
  }

  Widget _letters() {
    final exact = _variant != Variant.flutterCurve;
    final children = <Widget>[];
    for (var i = 0; i < _text.length; i++) {
      final p = _pop(i, _elapsed, exact: exact);
      final alpha = _alpha(i, _elapsed, exact: exact);
      final pal = _palette[i];
      final base = Color.from(alpha: 1, red: pal.$1, green: pal.$2, blue: pal.$3);
      final style = TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w700, color: base, height: 1.1);
      final glyph = Text(_text[i], style: style.copyWith(color: base.withValues(alpha: alpha)));
      final settled = (1 - p).abs() < .004 && alpha >= .999;
      final dy = .65 * _fontSize * (1 - p);
      var rot = .1745 * (1 - p);
      switch (_variant) {
        case Variant.flutterCurve:
        case Variant.preciseCurve:
          // Plain Text at rest, otherwise translate + rotate.
          if (settled) {
            children.add(glyph);
            continue;
          }
        case Variant.preciseKeep:
          break;
        case Variant.preciseTilted:
          rot += 1e-6;
        case Variant.preciseEarlySnap:
          if ((1 - p).abs() < .02) rot = 0;
          if (settled) {
            children.add(glyph);
            continue;
          }
      }
      children.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.translationValues(0, dy, 0)..rotateZ(rot),
        child: glyph,
      ));
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
