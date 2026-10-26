// The Tidewater app icon, defined once and drawn two ways: as SVG text
// (assets/branding/*.svg) and with a Canvas (the PNGs and the Windows .ico).
// Regenerate everything with:
//
//   flutter test tool/render_app_icon_test.dart
//
// Two flat (no gradients) designs, both in blues:
//   cookie: a scalloped sky-blue "cookie" (the album tile shape) on a blue tile,
//           with the wavy progress bar running through it.
//   record: a line-art vinyl record sinking into a rising tide, with the app's
//           coral cookie as its label.
import 'dart:math' as math;
import 'dart:ui' as ui;

const iconSize = 1024.0;

enum IconDesign { cookie, record }

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

// --- cookie design -----------------------------------------------------------

const _cookieBg = 0xFF1F5FC4;
const _cookieFill = 0xFF8FCFFF;
const _cookieInk = 0xFF0B2A57;
const _cookieTrack = 0xFF5C9BE0; // the ink at about a third, mixed into the cookie

const _cc = 512.0;
const _cookieRadius = 372.0;
const _waveFrom = 228.0;
const _waveTo = 572.0;
const _waveAmp = 52.0;
const _waveLength = 150.0;
const _lineW = 44.0;
const _handleX = 640.0;
const _handleW = 34.0;
const _handleH = 168.0;
const _trackFrom = 692.0;
const _trackTo = 800.0;

List<(double, double)> _cookieWave() => [
      for (var x = _waveFrom; x <= _waveTo + .001; x += 4)
        (x, _cc + _waveAmp * math.sin(2 * math.pi * (x - _waveFrom) / _waveLength)),
    ];

String _cookieSvg() => '''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" rx="232" fill="${_hex(_cookieBg)}"/>
  <path d="${_poly(_scallop(_cc, _cc, _cookieRadius, 9, .055), close: true)}" fill="${_hex(_cookieFill)}"/>
  <path d="${_poly(_cookieWave())}" fill="none" stroke="${_hex(_cookieInk)}" stroke-width="$_lineW" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="${_handleX - _handleW / 2}" y="${_cc - _handleH / 2}" width="$_handleW" height="$_handleH" rx="${_handleW / 2}" fill="${_hex(_cookieInk)}"/>
  <line x1="$_trackFrom" y1="$_cc" x2="$_trackTo" y2="$_cc" stroke="${_hex(_cookieTrack)}" stroke-width="$_lineW" stroke-linecap="round"/>
</svg>
''';

void _paintCookie(ui.Canvas canvas) {
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, iconSize, iconSize), _fill(_cookieBg));
  canvas.drawPath(_path(_scallop(_cc, _cc, _cookieRadius, 9, .055), close: true), _fill(_cookieFill));
  canvas.drawPath(_path(_cookieWave()), _stroke(_cookieInk, _lineW));
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(_handleX - _handleW / 2, _cc - _handleH / 2, _handleW, _handleH),
      const ui.Radius.circular(_handleW / 2),
    ),
    _fill(_cookieInk),
  );
  canvas.drawLine(const ui.Offset(_trackFrom, _cc), const ui.Offset(_trackTo, _cc), _stroke(_cookieTrack, _lineW));
}

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
const _boatScale = .8;
const _sail = 0xFFF4FBFF;
const _hull = 0xFFFF7E5F;

double _surfaceAt(double x) => _waterLevel + _tideAmp * math.sin(2 * math.pi * x / _tideLength + _tidePhase);

({
  List<(double, double)> hull,
  List<(double, double)> flag,
  (double, double) mastTop,
  (double, double) mastBase,
}) _boat() {
  final slope = _tideAmp * 2 * math.pi / _tideLength * math.cos(2 * math.pi * _boatX / _tideLength + _tidePhase);
  final tilt = math.atan(slope).clamp(-.17, .17) - .14; // the wave's slope plus a lean for character
  final by = _surfaceAt(_boatX) - 2; // hull bottom, level with the surface line
  (double, double) p(double dx, double dy) {
    final lx = dx * _boatScale;
    final ly = (dy - 10) * _boatScale; // measured up from the hull's bottom
    return (
      _boatX + math.cos(tilt) * lx - math.sin(tilt) * ly,
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

void _paintBoat(ui.Canvas canvas) {
  final b = _boat();
  void shape(List<(double, double)> pts, int color) {
    canvas.drawPath(_path(pts, close: true), _fill(color));
    canvas.drawPath(_path(pts, close: true), _stroke(color, 5));
  }

  canvas.drawLine(
    ui.Offset(b.mastTop.$1, b.mastTop.$2),
    ui.Offset(b.mastBase.$1, b.mastBase.$2),
    _stroke(_sail, 6),
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

void _paintRecord(ui.Canvas canvas, {required bool boat}) {
  const center = ui.Offset(_rx, _ry);
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
      IconDesign.cookie => _cookieSvg(),
      IconDesign.record => _recordSvg(),
    };

/// Draws [design] scaled to [size] pixels square, clipped to the rounded tile.
/// [boat] draws the record design's little sailboat; at taskbar sizes it is
/// only a smudge, so the Windows icon leaves it off its small frames.
void paintIcon(ui.Canvas canvas, double size, IconDesign design, {bool boat = true}) {
  canvas.save();
  canvas.scale(size / iconSize);
  canvas.clipRRect(
    ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(0, 0, iconSize, iconSize), const ui.Radius.circular(232)),
  );
  switch (design) {
    case IconDesign.cookie:
      _paintCookie(canvas);
    case IconDesign.record:
      _paintRecord(canvas, boat: boat);
  }
  canvas.restore();
}
