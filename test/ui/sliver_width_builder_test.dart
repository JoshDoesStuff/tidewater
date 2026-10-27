import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/widgets/sliver_width_builder.dart';

void main() {
  testWidgets('a grid inside SliverWidthBuilder is built once, not on every scroll frame', (tester) async {
    var builds = 0;
    var items = 0;
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          controller: controller,
          slivers: [
            SliverWidthBuilder(
              builder: (context, c) {
                builds++;
                return SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                  itemCount: 400,
                  itemBuilder: (context, i) {
                    items++;
                    return Text('item $i');
                  },
                );
              },
            ),
          ],
        ),
      ),
    ));
    expect(builds, 1);
    final firstScreen = items;
    for (var i = 0; i < 20; i++) {
      controller.jumpTo(controller.offset + 7);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(builds, 1, reason: 'scrolling does not rebuild the grid');
    // Only the rows that scrolled into view were built (not the whole screen again each frame).
    expect(items - firstScreen, lessThan(firstScreen), reason: 'items built: $items');
  });

  testWidgets('and builds again when its width changes', (tester) async {
    var builds = 0;
    Future<void> pumpAt(double width) => tester.pumpWidget(Center(
          child: SizedBox(
            width: width,
            height: 400,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: CustomScrollView(
                slivers: [
                  SliverWidthBuilder(builder: (context, c) {
                    builds++;
                    return const SliverToBoxAdapter(child: SizedBox(height: 10));
                  }),
                ],
              ),
            ),
          ),
        ));
    await pumpAt(500);
    expect(builds, 1);
    await pumpAt(700);
    expect(builds, 2);
  });
}
