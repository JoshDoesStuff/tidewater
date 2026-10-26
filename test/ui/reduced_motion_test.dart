import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/widgets/effects/eq_bars.dart';

Widget _app({required bool reduced}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: const Row(children: [EqBadge(animating: true), MiniEq(animating: true, color: Colors.white)]),
    );

void main() {
  testWidgets('the equalizer bars bounce normally', (tester) async {
    await tester.pumpWidget(_app(reduced: false));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('the equalizer bars hold still with reduced motion', (tester) async {
    await tester.pumpWidget(_app(reduced: true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
