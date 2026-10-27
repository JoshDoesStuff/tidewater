import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/image_cache_config.dart';
import 'package:tidewater/ui/widgets/cover_art.dart';

void main() {
  test('the cover memory cache holds thousands of grid covers, not the default 100 MiB worth', () {
    final cache = ImageCache();
    expect(cache.maximumSizeBytes, 100 << 20);
    configureImageCache(cache);
    expect(cache.maximumSize, 3000);
    // Grid covers decode at their drawn size (about 192 px on a full-screen grid).
    expect(cache.maximumSizeBytes, greaterThanOrEqualTo(2500 * 192 * 192 * 4));
  });

  test('covers decode at the width they are drawn, in 32 px steps, never above the fetched size', () {
    expect(CoverImage.decodeWidthFor(300, 170, 1), 192);
    expect(CoverImage.decodeWidthFor(300, 171, 1), 192, reason: 'a pixel apart shares one decoded copy');
    expect(CoverImage.decodeWidthFor(300, 170, 1.5), 256);
    expect(CoverImage.decodeWidthFor(300, 170, 2), isNull, reason: '340 px wanted: the full 300 px cover');
    expect(CoverImage.decodeWidthFor(800, 420, 1), 448);
    expect(CoverImage.decodeWidthFor(300, double.infinity, 1), isNull);
    expect(CoverImage.decodeWidthFor(300, 0, 1), isNull);
  });
}
