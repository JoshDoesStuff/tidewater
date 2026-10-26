// The Tidewater app icon, defined once and drawn two ways: as SVG text
// (assets/branding/tidewater.svg) and with a Canvas (the PNGs and the Windows
// .ico). Regenerate everything with:
//
//   flutter test tool/render_app_icon_test.dart
//
// The picture: a scalloped "cookie" in the app's coral (the album tile shape) on
// deep teal, with the wavy progress bar running through it: the squiggle played so
// far, the pill handle, and the flat track still to come.
import 'dart:math' as math;
import 'dart:ui' as ui;

const iconSize = 1024.0;

// Colors.
const bgTop = 0xFF16363F;
const bgBottom = 0xFF081920;
const cookieStart = 0xFFFFAA90;
const cookieEnd = 0xFFFF7E5F;
const ink = 0xFF0F2229;

// Geometry (in the 1024 box).
const _center = 512.0;
const _cookieRadius = 372.0;
const _lobes = 9;
const _lobeDepth = .055;
const _waveFrom = 228.0;
const _waveTo = 572.0;
const _waveAmp = 52.0;
const _waveLength = 150.0;
const _stroke = 44.0;
const _handleX = 640.0;
const _handleW = 34.0;
const _handleH = 168.0;
const _trackFrom = 692.0;
const _trackTo = 800.0;

List<(double, double)> cookiePoints() => [
      for (var i = 0; i < 240; i++)
        () {
          final a = 2 * math.pi * i / 240 - math.pi / 2;
          final r = _cookieRadius * (1 + _lobeDepth * math.cos(_lobes * a));
          return (_center + r * math.cos(a), _center + r * math.sin(a));
        }(),
    ];

List<(double, double)> wavePoints() => [
      for (var x = _waveFrom; x <= _waveTo + .001; x += 4)
        (x, _center + _waveAmp * math.sin(2 * math.pi * (x - _waveFrom) / _waveLength)),
    ];

String _poly(List<(double, double)> pts, {bool close = false}) {
  final b = StringBuffer();
  for (final (i, p) in pts.indexed) {
    b.write('${i == 0 ? 'M' : 'L'}${p.$1.toStringAsFixed(1)} ${p.$2.toStringAsFixed(1)}');
  }
  if (close) b.write('Z');
  return b.toString();
}

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String iconSvg() => '''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${_hex(bgTop)}"/>
      <stop offset="1" stop-color="${_hex(bgBottom)}"/>
    </linearGradient>
    <linearGradient id="cookie" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${_hex(cookieStart)}"/>
      <stop offset="1" stop-color="${_hex(cookieEnd)}"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="232" fill="url(#bg)"/>
  <path d="${_poly(cookiePoints(), close: true)}" fill="url(#cookie)"/>
  <path d="${_poly(wavePoints())}" fill="none" stroke="${_hex(ink)}" stroke-width="$_stroke" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="${_handleX - _handleW / 2}" y="${_center - _handleH / 2}" width="$_handleW" height="$_handleH" rx="${_handleW / 2}" fill="${_hex(ink)}"/>
  <line x1="$_trackFrom" y1="$_center" x2="$_trackTo" y2="$_center" stroke="${_hex(ink)}" stroke-opacity=".32" stroke-width="$_stroke" stroke-linecap="round"/>
</svg>
''';

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

  final full = const ui.Rect.fromLTWH(0, 0, iconSize, iconSize);
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(full, const ui.Radius.circular(232)),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(0, iconSize),
        [const ui.Color(bgTop), const ui.Color(bgBottom)],
      ),
  );
  canvas.drawPath(
    poly(cookiePoints(), close: true),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(_center - _cookieRadius, _center - _cookieRadius),
        const ui.Offset(_center + _cookieRadius, _center + _cookieRadius),
        [const ui.Color(cookieStart), const ui.Color(cookieEnd)],
      ),
  );
  final inkPaint = ui.Paint()
    ..color = const ui.Color(ink)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = _stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  canvas.drawPath(poly(wavePoints()), inkPaint);
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(_handleX - _handleW / 2, _center - _handleH / 2, _handleW, _handleH),
      const ui.Radius.circular(_handleW / 2),
    ),
    ui.Paint()..color = const ui.Color(ink),
  );
  canvas.drawLine(
    const ui.Offset(_trackFrom, _center),
    const ui.Offset(_trackTo, _center),
    inkPaint..color = const ui.Color(ink).withValues(alpha: .32),
  );
  canvas.restore();
}
