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

import 'package:flutter_test/flutter_test.dart';

import 'app_icon.dart';

/// The design the Windows build uses.
const windowsDesign = IconDesign.record;

/// Frames this size and up keep the boat; the small ones (the taskbar and the
/// title bar use 16 to 48 px) go without, where it only reads as a smudge.
const boatFromSize = 64;

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

void main() {
  testWidgets('render the app icon files', (tester) async {
    await tester.runAsync(() async {
      Directory('assets/branding').createSync(recursive: true);
      for (final f in Directory('assets/branding').listSync().whereType<File>()) {
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
}
