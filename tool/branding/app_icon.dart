// The Tidewater app icon, defined once and drawn two ways: as SVG text
// (assets/branding/*.svg) and with a Canvas (the PNGs and the Windows .ico).
// Regenerate everything with:
//
//   flutter test tool/branding/render_app_icon_test.dart
//
// The flat (no gradients) icon, in blues:
//   record: a line-art vinyl record sinking into a rising tide, with the app's
//           coral cookie as its label.
import 'dart:math' as math;
import 'dart:ui' as ui;

const iconSize = 1024.0;

enum IconDesign { record }

// --- shared helpers ----------------------------------------------------------

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _poly(List<(double, double)> pts, {bool close = false}) {
  final b = StringBuffer();
  for (final (i, p) in pts.indexed) {
    b.write('${i == 0 ? 'M' : 'L'}${p.$1.toStringAsFixed(1)} ${p.$2.toStringAsFixed(1)}');
  }
  if (close) b.write('Z');
  return b.toString();
}

ui.Path _path(List<(double, double)> pts, {bool close = false}) {
  final p = ui.Path()..moveTo(pts.first.$1, pts.first.$2);
  for (final pt in pts.skip(1)) {
    p.lineTo(pt.$1, pt.$2);
  }
  if (close) p.close();
  return p;
}

List<(double, double)> _scallop(double cx, double cy, double radius, int lobes, double depth) => [
      for (var i = 0; i < 240; i++)
        () {
          final a = 2 * math.pi * i / 240 - math.pi / 2;
          final r = radius * (1 + depth * math.cos(lobes * a));
          return (cx + r * math.cos(a), cy + r * math.sin(a));
        }(),
    ];

ui.Paint _stroke(int color, double width) => ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round
  ..color = ui.Color(color);

ui.Paint _fill(int color) => ui.Paint()..color = ui.Color(color);

// --- record design -----------------------------------------------------------

const _recBg = 0xFF1B57B8;
const _recLine = 0xFFD7F2FF;
const _recGroove1 = 0xFF86ADE6;
const _recGroove2 = 0xFF5F8DD6;
const _recShine = 0xFFB5CFF3;
const _recWater = 0xFF3F9BEE;
const _recWaterLine = 0xFF7CC4FF;
const _recSurface = 0xFFE4F7FF;
const _recLabel = 0xFFFF7E5F;
const _recHole = 0xFF123A72;

const _rx = 512.0;
const _ry = 530.0;
const _outer = 250.0;
const _grooves = [(180.0, 14.0), (132.0, 10.0)];
const _labelR = 88.0;
const _waterLevel = 640.0;
const _tideAmp = 30.0;
const _tideLength = 300.0;
const _tidePhase = -2.87; // puts a trough under the record's middle
const _shineR = 218.0;
const _shineFrom = 3.55;
const _shineTo = 4.15;

List<(double, double)> _tide({double drop = 0, double amp = _tideAmp, double phase = _tidePhase}) => [
      for (var x = -8.0; x <= iconSize + 8; x += 8)
        (x, _waterLevel + drop + amp * math.sin(2 * math.pi * x / _tideLength + phase)),
    ];

// A tiny boat riding the surface on the right: a shallow hull, one mast and a
// pennant flag (after a quick sketch, cleaned up). It tilts to follow the wave
// under it and sits a little into the water.
const _boatX = 898.0;
const _boatScale = 1.1;
const _sail = 0xFFF4FBFF;
const _hull = 0xFFFF7E5F;

double _surfaceAt(double x) => _waterLevel + _tideAmp * math.sin(2 * math.pi * x / _tideLength + _tidePhase);

typedef _BoatShapes = ({
  List<(double, double)> hull,
  List<(double, double)> flag,
  (double, double) mastTop,
  (double, double) mastBase,
});

/// The icon's boat: on the wave under [_boatX], leaning a bit more than its slope.
_BoatShapes _boat() {
  final slope = _tideAmp * 2 * math.pi / _tideLength * math.cos(2 * math.pi * _boatX / _tideLength + _tidePhase);
  final tilt = math.atan(slope).clamp(-.17, .17) - .14; // the wave's slope plus a lean for character
  return _boatAt(x: _boatX, by: _surfaceAt(_boatX) - 2, tilt: tilt, scale: _boatScale);
}

/// A boat whose hull bottom is at ([x], [by]), turned by [tilt] radians, [scale] times
/// the base drawing.
_BoatShapes _boatAt({required double x, required double by, required double tilt, required double scale}) {
  (double, double) p(double dx, double dy) {
    final lx = dx * scale;
    final ly = (dy - 10) * scale; // measured up from the hull's bottom
    return (
      x + math.cos(tilt) * lx - math.sin(tilt) * ly,
      by + math.sin(tilt) * lx + math.cos(tilt) * ly,
    );
  }

  // The hull's ends are smooth curves (sampled), so each side reads as one bend
  // instead of two straight edges meeting at a corner.
  (double, double) curve((double, double) a, (double, double) c, (double, double) b, double t) =>
      ((1 - t) * (1 - t) * a.$1 + 2 * (1 - t) * t * c.$1 + t * t * b.$1, (1 - t) * (1 - t) * a.$2 + 2 * (1 - t) * t * c.$2 + t * t * b.$2);
  final hull = [
    p(-52, -16),
    p(52, -16),
    for (var i = 1; i <= 8; i++) p(curve((52.0, -16.0), (47.0, 10.0), (28.0, 10.0), i / 8).$1, curve((52.0, -16.0), (47.0, 10.0), (28.0, 10.0), i / 8).$2),
    for (var i = 1; i <= 8; i++) p(curve((-28.0, 10.0), (-47.0, 10.0), (-52.0, -16.0), i / 8).$1, curve((-28.0, 10.0), (-47.0, 10.0), (-52.0, -16.0), i / 8).$2),
  ];

  return (
    hull: hull,
    flag: [p(3, -96), p(3, -64), p(46, -80)],
    mastTop: p(0, -98),
    mastBase: p(0, -16),
  );
}

String _boatSvg() {
  final b = _boat();
  String shape(List<(double, double)> pts, int color) =>
      '<path d="${_poly(pts, close: true)}" fill="${_hex(color)}" stroke="${_hex(color)}" stroke-width="6" stroke-linejoin="round"/>';
  return '''<line x1="${b.mastTop.$1}" y1="${b.mastTop.$2.toStringAsFixed(1)}" x2="${b.mastBase.$1}" y2="${b.mastBase.$2.toStringAsFixed(1)}" stroke="${_hex(_sail)}" stroke-width="8" stroke-linecap="round"/>
    ${shape(b.flag, _sail)}
    ${shape(b.hull, _hull)}
''';
}

void _paintBoat(ui.Canvas canvas, [_BoatShapes? shapes, double strokeScale = 1]) {
  final b = shapes ?? _boat();
  void shape(List<(double, double)> pts, int color) {
    canvas.drawPath(_path(pts, close: true), _fill(color));
    canvas.drawPath(_path(pts, close: true), _stroke(color, 5 * strokeScale));
  }

  canvas.drawLine(
    ui.Offset(b.mastTop.$1, b.mastTop.$2),
    ui.Offset(b.mastBase.$1, b.mastBase.$2),
    _stroke(_sail, 6 * strokeScale),
  );
  shape(b.flag, _sail);
  shape(b.hull, _hull);
}

List<(double, double)> _waterShape() => [..._tide(), (iconSize + 8, iconSize + 8), (-8.0, iconSize + 8)];

String _recordSvg() {
  String arcPoint(double a) =>
      '${(_rx + _shineR * math.cos(a)).toStringAsFixed(1)} ${(_ry + _shineR * math.sin(a)).toStringAsFixed(1)}';
  String rings(int outer, List<int> grooves) {
    final b = StringBuffer('<circle cx="$_rx" cy="$_ry" r="$_outer" fill="none" stroke="${_hex(outer)}" stroke-width="30"/>');
    for (final (i, g) in _grooves.indexed) {
      b.write('\n    <circle cx="$_rx" cy="$_ry" r="${g.$1}" fill="none" stroke="${_hex(grooves[i])}" stroke-width="${g.$2}"/>');
    }
    return b.toString();
  }

  return '''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <clipPath id="tile"><rect width="1024" height="1024" rx="232"/></clipPath>
  </defs>
  <g clip-path="url(#tile)">
    <rect width="1024" height="1024" fill="${_hex(_recBg)}"/>
    ${rings(_recLine, [_recGroove1, _recGroove2])}
    <path d="M${arcPoint(_shineFrom)} A$_shineR $_shineR 0 0 1 ${arcPoint(_shineTo)}" fill="none" stroke="${_hex(_recShine)}" stroke-width="16" stroke-linecap="round"/>
    <path d="${_poly(_scallop(_rx, _ry, _labelR, 6, .085), close: true)}" fill="${_hex(_recLabel)}"/>
    <circle cx="$_rx" cy="$_ry" r="18" fill="${_hex(_recHole)}"/>
    ${_boatSvg()}
    <path d="${_poly(_waterShape(), close: true)}" fill="${_hex(_recWater)}"/>
    <path d="${_poly(_tide(drop: 96, amp: 22, phase: _tidePhase + 1.6))}" fill="none" stroke="${_hex(_recWaterLine)}" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="${_poly(_tide())}" fill="none" stroke="${_hex(_recSurface)}" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>
  </g>
</svg>
''';
}

void _paintRecord(ui.Canvas canvas, {required bool boat, required bool simple}) {
  const center = ui.Offset(_rx, _ry);
  if (simple) {
    // Taskbar sizes: a few bold shapes, no hairline rings, shine or second wave,
    // so it stays clean instead of crunchy at 16 to 48 px.
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, iconSize, iconSize), _fill(_recBg));
    // Same tide as the full icon, so the record is sunk about a third of the way.
    const bold = ui.Offset(_rx, 500);
    canvas.drawCircle(bold, 290, _stroke(_recLine, 84));
    canvas.drawPath(_path(_scallop(_rx, 500, 138, 6, .085), close: true), _fill(_recLabel));
    canvas.drawCircle(bold, 36, _fill(_recHole));
    canvas.drawPath(_path(_waterShape(), close: true), _fill(_recWater));
    canvas.drawPath(_path(_tide()), _stroke(_recSurface, 44));
    return;
  }
  void rings(int outer, List<int> grooves) {
    canvas.drawCircle(center, _outer, _stroke(outer, 30));
    for (final (i, g) in _grooves.indexed) {
      canvas.drawCircle(center, g.$1, _stroke(grooves[i], g.$2));
    }
  }

  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, iconSize, iconSize), _fill(_recBg));
  rings(_recLine, [_recGroove1, _recGroove2]);
  canvas.drawArc(
    ui.Rect.fromCircle(center: center, radius: _shineR),
    _shineFrom,
    _shineTo - _shineFrom,
    false,
    _stroke(_recShine, 16),
  );
  canvas.drawPath(_path(_scallop(_rx, _ry, _labelR, 6, .085), close: true), _fill(_recLabel));
  canvas.drawCircle(center, 18, _fill(_recHole));
  if (boat) _paintBoat(canvas); // before the water, so the water covers the hull's bottom
  canvas.drawPath(_path(_waterShape(), close: true), _fill(_recWater));
  canvas.drawPath(_path(_tide(drop: 96, amp: 22, phase: _tidePhase + 1.6)), _stroke(_recWaterLine, 12));
  canvas.drawPath(_path(_tide()), _stroke(_recSurface, 20));
}

// --- public ------------------------------------------------------------------

String iconSvg(IconDesign design) => switch (design) {
      IconDesign.record => _recordSvg(),
    };

/// Draws [design] scaled to [size] pixels square, clipped to the rounded tile.
/// [boat] draws the record design's little sailboat; at taskbar sizes it is
/// only a smudge, so the Windows icon leaves it off its small frames. [simple]
/// also drops the fine detail (rings, shine, second wave) for those sizes.
void paintIcon(ui.Canvas canvas, double size, IconDesign design, {bool boat = true, bool simple = false}) {
  canvas.save();
  canvas.scale(size / iconSize);
  canvas.clipRRect(
    ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(0, 0, iconSize, iconSize), const ui.Radius.circular(232)),
  );
  switch (design) {
    case IconDesign.record:
      _paintRecord(canvas, boat: boat, simple: simple);
  }
  canvas.restore();
}

// --- banner ------------------------------------------------------------------

/// The wide scene for the GitHub social preview: one tide across the whole width,
/// the record sinking on the left, the boat on a wave on the right. The caller adds
/// the name in the middle.
void paintBanner(ui.Canvas canvas, double w, double h) {
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, h), _fill(_recBg));
  const level = 410.0;
  const length = 380.0;
  const amp = 26.0;
  // A trough under the record's middle, like the icon.
  const phase = 1.5708 - 2 * math.pi * 230 / length;
  double surface(double x) => level + amp * math.sin(2 * math.pi * x / length + phase);
  List<(double, double)> tide({double drop = 0, double a = amp, double ph = 0}) => [
        for (var x = -8.0; x <= w + 8; x += 8) (x, level + drop + a * math.sin(2 * math.pi * x / length + phase + ph)),
      ];

  // Record: the icon's record at 0.8 scale.
  const k = .64;
  const c = ui.Offset(212, 322);
  canvas.drawCircle(c, _outer * k, _stroke(_recLine, 30 * k));
  for (final (i, g) in _grooves.indexed) {
    canvas.drawCircle(c, g.$1 * k, _stroke(i == 0 ? _recGroove1 : _recGroove2, g.$2 * k));
  }
  canvas.drawArc(ui.Rect.fromCircle(center: c, radius: _shineR * k), _shineFrom, _shineTo - _shineFrom, false, _stroke(_recShine, 16 * k));
  canvas.drawPath(_path(_scallop(c.dx, c.dy, _labelR * k, 6, .085), close: true), _fill(_recLabel));
  canvas.drawCircle(c, 18 * k, _fill(_recHole));

  // Boat: a good size, on the slope of a wave near the right edge.
  const bx = 1100.0;
  final slope = amp * 2 * math.pi / length * math.cos(2 * math.pi * bx / length + phase);
  final tilt = math.atan(slope).clamp(-.12, .12) - .08;
  _paintBoat(canvas, _boatAt(x: bx, by: surface(bx) - 2, tilt: tilt, scale: 1.3), 1.3);

  // Water across the full width, on top of the record's and the boat's bottoms.
  canvas.drawPath(_path([...tide(), (w + 8, h + 8), (-8.0, h + 8)], close: true), _fill(_recWater));
  canvas.drawPath(_path(tide(drop: 70, a: 20, ph: 1.6)), _stroke(_recWaterLine, 10));
  canvas.drawPath(_path(tide(drop: 150, a: 16, ph: 3.1)), _stroke(_recWaterLine.withAlpha(0xFF), 8));
  canvas.drawPath(_path(tide()), _stroke(_recSurface, 18));
}

extension on int {
  int withAlpha(int a) => (a << 24) | (this & 0xFFFFFF);
}
