import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/widgets/effects/stagger_in.dart';

void main() {
  test('the wave runs along the whole of the first eight rows, whatever the width', () {
    for (final columns in [3, 8, 12, 18]) {
      final indexes = [for (var i = 0; i < columns * 8; i++) StaggerIn.wave(i, columns)];
      // Every cell past the first row and column has a delay: the whole screen animates in.
      for (var i = 0; i < columns * 8; i++) {
        final row = i ~/ columns;
        final col = i % columns;
        expect(indexes[i], row + col);
      }
      expect(StaggerIn.wave(columns * 8, columns), 0, reason: 'rows scrolled in later just fade');
    }
  });

  test('the column count matches what Flutter\'s max-extent grid picks', () {
    expect(StaggerIn.columnsFor(3300, 280, 14), 12);
    expect(StaggerIn.columnsFor(1000, 280, 14), 4);
    expect(StaggerIn.columnsFor(280, 280, 14), 1);
  });
}
