import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/image_cache_config.dart';

void main() {
  test('the cover memory cache holds a thousand covers, not the default 100 MiB worth', () {
    final cache = ImageCache();
    expect(cache.maximumSizeBytes, 100 << 20);
    configureImageCache(cache);
    expect(cache.maximumSize, 1000);
    expect(cache.maximumSizeBytes, greaterThanOrEqualTo(1000 * 300 * 300 * 4));
  });
}
