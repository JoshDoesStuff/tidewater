import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/theme/settled_theme.dart';

void main() {
  testWidgets('a widget reading the settled theme is not rebuilt while the theme animates', (tester) async {
    final settled = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal));
    var builds = 0;
    final reader = Builder(builder: (context) {
      builds++;
      return Text('${SettledTheme.of(context).colorScheme.primary}', textDirection: TextDirection.ltr);
    });
    Widget frame(Color animated) => SettledTheme(
          data: settled,
          child: Theme(data: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: animated)), child: reader),
        );

    await tester.pumpWidget(frame(Colors.red));
    await tester.pumpWidget(frame(Colors.orange));
    await tester.pumpWidget(frame(Colors.yellow));
    expect(builds, 1);
    expect(find.text('${settled.colorScheme.primary}'), findsOneWidget);
  });

  testWidgets('without a settled theme it falls back to the current one', (tester) async {
    final theme = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo));
    late ThemeData seen;
    await tester.pumpWidget(Theme(
      data: theme,
      child: Builder(builder: (context) {
        seen = SettledTheme.of(context);
        return const SizedBox();
      }),
    ));
    expect(seen.colorScheme.primary, theme.colorScheme.primary);
  });
}
