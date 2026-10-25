// Publishes a fake "now playing" to the Windows media overlay and prints every
// button press it receives, for about 60 seconds. Pair it with
// tool/smtc_check.ps1, which reads the session back through the Windows API
// and presses its buttons.
//
//   flutter run -d windows -t tool/smtc_probe_main.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tidewater/app/playback/smtc_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final smtc = await SmtcControls.create();
  if (smtc == null) {
    stdout.writeln('PROBE FAIL smtc unavailable');
    exit(1);
  }
  stdout.writeln('PROBE smtc created');
  smtc.buttons.listen((b) => stdout.writeln('PROBE button ${b.name}'));
  await smtc.setTrack(title: 'Probe Song', artist: 'Probe Artist', album: 'Probe Album');
  await smtc.setPlaying(true);
  await smtc.setTimeline(position: const Duration(seconds: 12), duration: const Duration(minutes: 3, seconds: 30));
  stdout.writeln('PROBE published');
  await Future<void>.delayed(const Duration(seconds: 75));
  await smtc.clear();
  stdout.writeln('PROBE done');
  exit(0);
}
