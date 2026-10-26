import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/settings_providers.dart';

void main() {
  test('one-word titles keep the old 1x pace, then it climbs with the length', () {
    expect(titlePace('Xeon'), 1.0);
    expect(titlePace(''), 1.0);
    expect(titlePace('Head Full of Nightmares'), closeTo(1.3, .001));
    expect(titlePace('RondeauX of RagnaroQ -Crescendo of Cataclysm-'), closeTo(1.7, .02));
    expect(titlePace('x' * 100), closeTo(1.7, .001));
    final a = titlePace('blue flavor'), b = titlePace('x' * 32);
    expect(a, inInclusiveRange(1.0, 1.3));
    expect(b, inInclusiveRange(1.3, 1.7));
    expect(a, lessThan(b));
  });
}
