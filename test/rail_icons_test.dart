import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/destinations.dart';
import 'package:tidewater/ui/shell/rail_icon_motion.dart';

void main() {
  testWidgets('every sidebar icon file loads and draws at any point of its animation', (tester) async {
    for (final d in Destination.values) {
      final future = RailIcons.load(d);
      final comp = future == null ? null : await tester.runAsync(() => future);
      const drawn = {Destination.home, Destination.library, Destination.liked};
      if (!drawn.contains(d)) expect(comp, isNotNull, reason: '${d.label} has an icon file');
      for (final t in [0.0, .3, .7, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(home: Center(child: railIconMotion(d, t, Colors.white, composition: comp))),
        );
        expect(tester.takeException(), isNull, reason: '${d.label} at $t');
      }
    }
  });
}
