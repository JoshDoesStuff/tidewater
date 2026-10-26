// The Tidewater app icon, defined once and drawn two ways: as SVG text
// (assets/branding/tidewater.svg) and with a Canvas (the PNGs and the Windows
// .ico). Regenerate everything with:
//
//   flutter test tool/render_app_icon_test.dart
//
// The picture: a line-art vinyl record (thick round strokes, like the app's
// Material shapes) sinking into a rising tide. Blue water covers the lower part
// of the record, with a light wave line on the surface. The record's label is the
// app's scalloped coral "cookie".
import 'dart:math' as math;
import 'dart:ui' as ui;

const iconSize = 1024.0;

// Colors.
const bgTop = 0xFF2B6FD4;
const bgBottom = 0xFF0A2447;
const lineColor = 0xFFD7F2FF;
const waterTop = 0xFF5BC0FF;
const waterBottom = 0xFF1457B8;
const surfaceLine = 0xFFE4F7FF;
const cookieStart = 0xFFFFAA90;
const cookieEnd = 0xFFFF7E5F;
const holeColor = 0xFF123A72;

// Geometry (in the 1024 box).
const _cx = 512.0;
const _cy = 452.0;
const _outer = 296.0;
const _grooves = [(214.0, 16.0, .55), (156.0, 12.0, .38)];
const _labelRadius = 104.0;
const _lobes = 6;
const _lobeDepth = .085;
const _waterLevel = 640.0;
const _waveAmp = 30.0;
const _waveLength = 300.0;

List<(double, double)> cookiePoints() => [
      for (var i = 0; i < 240; i++)
        () {
          final a = 2 * math.pi * i / 240 - math.pi / 2;
          final r = _labelRadius * (1 + _lobeDepth * math.cos(_lobes * a));
          return (_cx + r * math.cos(a), _cy + r * math.sin(a));
        }(),
    ];

double _surfaceY(double x, {double drop = 0, double amp = _waveAmp, double phase = 0}) =>
    _waterLevel + drop + amp * math.sin(2 * math.pi * x / _waveLength + phase);

List<(double, double)> wave({double drop = 0, double amp = _waveAmp, double phase = 0}) =>
    [for (var x = -8.0; x <= iconSize + 8; x += 8) (x, _surfaceY(x, drop: drop, amp: amp, phase: phase))];

/// The shine on the record's upper left, as an arc on the outer groove.
const _shineRadius = 258.0;
const _shineFrom = 3.55; // radians, measured from the +x axis, clockwise (y down)
const _shineTo = 4.15;

String _poly(List<(double, double)> pts, {bool close = false}) {
  final b = StringBuffer();
  for (final (i, p) in pts.indexed) {
    b.write('${i == 0 ? 'M' : 'L'}${p.$1.toStringAsFixed(1)} ${p.$2.toStringAsFixed(1)}');
  }
  if (close) b.write('Z');
  return b.toString();
}

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String iconSvg() {
  final water = [...wave(), (iconSize + 8, iconSize + 8), (-8.0, iconSize + 8)];
  String arcPoint(double a) =>
      '${(_cx + _shineRadius * math.cos(a)).toStringAsFixed(1)} ${(_cy + _shineRadius * math.sin(a)).toStringAsFixed(1)}';
  return '''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${_hex(bgTop)}"/>
      <stop offset="1" stop-color="${_hex(bgBottom)}"/>
    </linearGradient>
    <linearGradient id="water" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${_hex(waterTop)}"/>
      <stop offset="1" stop-color="${_hex(waterBottom)}"/>
    </linearGradient>
    <linearGradient id="cookie" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${_hex(cookieStart)}"/>
      <stop offset="1" stop-color="${_hex(cookieEnd)}"/>
    </linearGradient>
    <clipPath id="tile"><rect width="1024" height="1024" rx="232"/></clipPath>
  </defs>
  <g clip-path="url(#tile)">
    <rect width="1024" height="1024" fill="url(#bg)"/>
    <circle cx="$_cx" cy="$_cy" r="$_outer" fill="none" stroke="${_hex(lineColor)}" stroke-width="34"/>
    ${[for (final (r, w, a) in _grooves) '<circle cx="$_cx" cy="$_cy" r="$r" fill="none" stroke="${_hex(lineColor)}" stroke-opacity="$a" stroke-width="$w"/>'].join('\n    ')}
    <path d="M${arcPoint(_shineFrom)} A$_shineRadius $_shineRadius 0 0 1 ${arcPoint(_shineTo)}" fill="none" stroke="#ffffff" stroke-opacity=".7" stroke-width="16" stroke-linecap="round"/>
    <path d="${_poly(cookiePoints(), close: true)}" fill="url(#cookie)"/>
    <circle cx="$_cx" cy="$_cy" r="22" fill="${_hex(holeColor)}"/>
    <path d="${_poly(water, close: true)}" fill="url(#water)" fill-opacity=".9"/>
    <path d="${_poly(wave(drop: 96, amp: 22, phase: 1.6))}" fill="none" stroke="#ffffff" stroke-opacity=".22" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="${_poly(wave())}" fill="none" stroke="${_hex(surfaceLine)}" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>
  </g>
</svg>
''';
}

/// Draws the icon scaled to [size] pixels square.
void paintIcon(ui.Canvas canvas, double size) {
  final k = size / iconSize;
  canvas.save();
  canvas.scale(k);
  ui.Path poly(List<(double, double)> pts, {bool close = false}) {
    final p = ui.Path()..moveTo(pts.first.$1, pts.first.$2);
    for (final pt in pts.skip(1)) {
      p.lineTo(pt.$1, pt.$2);
    }
    if (close) p.close();
    return p;
  }

  ui.Paint stroke(int color, double width, {double alpha = 1}) => ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round
    ..color = ui.Color(color).withValues(alpha: alpha);

  final full = const ui.Rect.fromLTWH(0, 0, iconSize, iconSize);
  canvas.clipRRect(ui.RRect.fromRectAndRadius(full, const ui.Radius.circular(232)));
  canvas.drawRect(
    full,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(0, iconSize),
        [const ui.Color(bgTop), const ui.Color(bgBottom)],
      ),
  );
  const center = ui.Offset(_cx, _cy);
  canvas.drawCircle(center, _outer, stroke(lineColor, 34));
  for (final (r, w, a) in _grooves) {
    canvas.drawCircle(center, r, stroke(lineColor, w, alpha: a));
  }
  canvas.drawArc(
    ui.Rect.fromCircle(center: center, radius: _shineRadius),
    _shineFrom,
    _shineTo - _shineFrom,
    false,
    stroke(0xFFFFFFFF, 16, alpha: .7),
  );
  canvas.drawPath(
    poly(cookiePoints(), close: true),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(_cx - _labelRadius, _cy - _labelRadius),
        const ui.Offset(_cx + _labelRadius, _cy + _labelRadius),
        [const ui.Color(cookieStart), const ui.Color(cookieEnd)],
      ),
  );
  canvas.drawCircle(center, 22, ui.Paint()..color = const ui.Color(holeColor));

  final waterShape = [...wave(), (iconSize + 8, iconSize + 8), (-8.0, iconSize + 8)];
  canvas.drawPath(
    poly(waterShape, close: true),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, _waterLevel - _waveAmp),
        const ui.Offset(0, iconSize),
        [const ui.Color(waterTop).withValues(alpha: .9), const ui.Color(waterBottom).withValues(alpha: .9)],
      ),
  );
  canvas.drawPath(poly(wave(drop: 96, amp: 22, phase: 1.6)), stroke(0xFFFFFFFF, 12, alpha: .22));
  canvas.drawPath(poly(wave()), stroke(surfaceLine, 20));
  canvas.restore();
}
