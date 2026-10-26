import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/settings_providers.dart';

void main() {
  test('short titles swap at 1.3x, long ones at 1.7x, and the rest in between', () {
    expect(titlePace('Head Full of Nightmares'), closeTo(1.3, .05));
    expect(titlePace('RondeauX of RagnaroQ -Crescendo of Cataclysm-'), closeTo(1.7, .01));
    expect(titlePace('x' * 100), closeTo(1.7, .001));
    expect(titlePace(''), closeTo(1.3, .001));
    final mid = titlePace('x' * 32);
    expect(mid, greaterThan(1.3));
    expect(mid, lessThan(1.7));
  });
}
