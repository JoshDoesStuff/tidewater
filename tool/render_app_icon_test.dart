// Writes the app icon files. Not part of the normal suite:
//
//   flutter test tool/render_app_icon_test.dart
//
// assets/branding/tidewater_<design>.svg and .png (1024 px) for each design, and
// the Windows icon (windows/runner/resources/app_icon.ico, PNG frames from 16 to
// 256 px) from [windowsDesign].
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'app_icon.dart';

/// The design the Windows build uses.
const windowsDesign = IconDesign.record;

/// Frames this size and up keep the boat and the fine detail; the smaller ones (the taskbar and the
/// title bar use 16 to 96 px) are the bold simplified version, where it would only be a smudge.
const boatFromSize = 128;

/// Every size Windows asks for at the usual display scales (the taskbar uses 24, 30,
/// 36, 48 and 60 px at 100, 125, 150, 200 and 250 %; a missing size is scaled from a
/// neighbor, which is what makes an icon look soft or crunchy).
const iconSizes = [16, 20, 24, 30, 32, 36, 40, 48, 60, 64, 72, 80, 96, 128, 256];

Future<Uint8List> _png(int size, IconDesign design) async {
  final recorder = ui.PictureRecorder();
  paintIcon(ui.Canvas(recorder), size.toDouble(), design, boat: size >= boatFromSize, simple: size < boatFromSize);
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// An .ico holding one PNG per size (Windows Vista and later read these).
Uint8List _ico(Map<int, Uint8List> frames) {
  final sizes = frames.keys.toList();
  final header = ByteData(6 + 16 * sizes.length)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, sizes.length, Endian.little);
  var offset = 6 + 16 * sizes.length;
  for (final (i, s) in sizes.indexed) {
    final png = frames[s]!;
    final at = 6 + 16 * i;
    header.setUint8(at, s >= 256 ? 0 : s);
    header.setUint8(at + 1, s >= 256 ? 0 : s);
    header.setUint16(at + 4, 1, Endian.little); // planes
    header.setUint16(at + 6, 32, Endian.little); // bits per pixel
    header.setUint32(at + 8, png.length, Endian.little);
    header.setUint32(at + 12, offset, Endian.little);
    offset += png.length;
  }
  final out = BytesBuilder()..add(header.buffer.asUint8List());
  for (final s in sizes) {
    out.add(frames[s]!);
  }
  return out.toBytes();
}

/// Bundled Roboto so the banner text renders the same everywhere (the SDK ships it
/// for the test engine).
Future<void> _loadRoboto() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final roboto = FontLoader('Roboto');
  for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
    final bytes = await File('$sdk/bin/cache/artifacts/material_fonts/$name').readAsBytes();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();
}

/// The GitHub social preview image: 1280 x 640, the icon on the left and the
/// name beside it.
Future<Uint8List> _banner() async {
  const w = 1280, h = 640;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFF0B2A57));
  canvas.save();
  canvas.translate(96, 80);
  paintIcon(canvas, 480, IconDesign.record);
  canvas.restore();
  ui.Paragraph text(String s, double size, ui.FontWeight weight, int color, double width) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: weight))
      ..pushStyle(ui.TextStyle(color: ui.Color(color), fontFamily: 'Roboto', fontSize: size, fontWeight: weight, letterSpacing: size > 60 ? -2 : 0))
      ..addText(s);
    return b.build()..layout(ui.ParagraphConstraints(width: width));
  }

  canvas.drawParagraph(text('Tidewater', 132, ui.FontWeight.bold, 0xFFF4FBFF, 620), const ui.Offset(640, 224));
  canvas.drawParagraph(text('A Navidrome client for Windows', 38, ui.FontWeight.normal, 0xFF8FCFFF, 640), const ui.Offset(644, 380));
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('render the app icon files', (tester) async {
    await tester.runAsync(() async {
      Directory('assets/branding').createSync(recursive: true);
      for (final f in Directory('assets/branding').listSync().whereType<File>()) {
        if (f.uri.pathSegments.last.startsWith('tidewater_banner')) continue;
        f.deleteSync(); // drop files from older designs
      }
      for (final design in IconDesign.values) {
        File('assets/branding/tidewater_${design.name}.svg').writeAsStringSync(iconSvg(design));
        File('assets/branding/tidewater_${design.name}.png').writeAsBytesSync(await _png(1024, design));
      }
      final frames = <int, Uint8List>{
        for (final s in iconSizes) s: await _png(s, windowsDesign),
      };
      File('windows/runner/resources/app_icon.ico').writeAsBytesSync(_ico(frames));
    });
    expect(File('windows/runner/resources/app_icon.ico').lengthSync(), greaterThan(1000));
  });

  testWidgets('render the GitHub banner', (tester) async {
    await tester.runAsync(() async {
      await _loadRoboto();
      File('assets/branding/tidewater_banner_1280x640.png').writeAsBytesSync(await _banner());
    });
    expect(File('assets/branding/tidewater_banner_1280x640.png').lengthSync(), greaterThan(1000));
  });
}
