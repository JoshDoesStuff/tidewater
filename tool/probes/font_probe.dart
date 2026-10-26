// Renders text with the font's variable axes in the real Windows engine and
// saves a PNG, to see whether fontVariations are honored there.
// Run: flutter run -d windows -t tool/probes/font_probe.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

final _key = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.white,
      body: RepaintBoundary(
        key: _key,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final v in <(String, List<FontVariation>, FontWeight?)>[
              ('default', const [], null),
              ('weight w900', const [], FontWeight.w900),
              ('wght 900', const [FontVariation('wght', 900)], null),
              ('wght 200', const [FontVariation('wght', 200)], null),
              ('wdth 150', const [FontVariation('wdth', 150)], null),
              ('wdth 60', const [FontVariation('wdth', 60)], null),
              ('ROND 100', const [FontVariation('ROND', 100)], null),
              ('ROND 0', const [FontVariation('ROND', 0)], null),
            ])
              Text('Tidewater Rag ${v.$1}',
                  style: TextStyle(
                      fontFamily: 'GoogleSansFlex', fontSize: 40, color: Colors.black, fontWeight: v.$3, fontVariations: v.$2)),
          ]),
        ),
      ),
    ),
  ));
  await Future<void>.delayed(const Duration(seconds: 3));
  final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final data = await (await b.toImage()).toByteData(format: ui.ImageByteFormat.png);
  File('${Platform.environment['TEMP']}\font_probe.png').writeAsBytesSync(data!.buffer.asUint8List());
  exit(0);
}
