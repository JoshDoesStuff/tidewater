// Writes the app icon files. Not part of the normal suite:
//
//   flutter test tool/render_app_icon_test.dart
//
// assets/branding/tidewater.svg and tidewater_1024.png, and the Windows icon
// (windows/runner/resources/app_icon.ico, PNG frames from 16 to 256 px).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'app_icon.dart';

Future<Uint8List> _png(int size) async {
  final recorder = ui.PictureRecorder();
  paintIcon(ui.Canvas(recorder), size.toDouble());
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
      File('assets/branding/tidewater.svg').writeAsStringSync(iconSvg());
      File('assets/branding/tidewater_1024.png').writeAsBytesSync(await _png(1024));
      final frames = <int, Uint8List>{for (final s in [16, 24, 32, 48, 64, 128, 256]) s: await _png(s)};
      File('windows/runner/resources/app_icon.ico').writeAsBytesSync(_ico(frames));
    });
    expect(File('windows/runner/resources/app_icon.ico').lengthSync(), greaterThan(1000));
  });
}
