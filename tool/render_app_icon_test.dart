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

/// Google Sans Flex (variable, OFL; see third-party-licenses/google-sans-flex-OFL.txt)
/// for the banner's name: the Material 3 Expressive typeface, with a roundness axis.
Future<void> _loadGoogleSansFlex() async {
  final bytes = await File('tool/fonts/GoogleSansFlex.ttf').readAsBytes();
  final flex = FontLoader('GoogleSansFlex')..addFont(Future.value(ByteData.sublistView(bytes)));
  await flex.load();
}

/// The GitHub social preview image: 1280 x 640, the icon on the left and the
/// name beside it.
Future<Uint8List> _banner() async {
  const w = 1280, h = 640;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  paintBanner(canvas, w.toDouble(), h.toDouble());
  // Heavy and wide, with a large optical size: the expressive headline look.
  ui.Paragraph name(double size) {
    final style = ui.TextStyle(
      color: const ui.Color(0xFFF4FBFF),
      fontFamily: 'GoogleSansFlex',
      fontSize: size,
      letterSpacing: -size * .01,
      fontVariations: [
        const ui.FontVariation('ROND', 100), // fully rounded
        const ui.FontVariation('wght', 800),
        const ui.FontVariation('wdth', 105),
        const ui.FontVariation('opsz', 144),
      ],
    );
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'GoogleSansFlex', fontSize: size))
      ..pushStyle(style)
      ..addText('Tidewater');
    return b.build()..layout(const ui.ParagraphConstraints(width: 1000));
  }

  // As big as fits between the record and the boat.
  var size = 240.0;
  var title = name(size);
  while (title.longestLine > 600 && size > 60) {
    size -= 4;
    title = name(size);
  }
  canvas.drawParagraph(title, ui.Offset((w - title.longestLine) / 2 + 50, 215 - title.height / 2));
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
      await _loadGoogleSansFlex();
      File('assets/branding/tidewater_banner_1280x640.png').writeAsBytesSync(await _banner());
    });
    expect(File('assets/branding/tidewater_banner_1280x640.png').lengthSync(), greaterThan(1000));
  });
}
