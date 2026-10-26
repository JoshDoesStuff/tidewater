import 'package:flutter/painting.dart';

/// How many decoded covers stay in memory. The Flutter default is 1000 pictures
/// but only 100 MiB, which is about 280 covers at 300 px, so scrolling back
/// through a big Library decoded covers again. This keeps a thousand (a 300 px
/// cover is about 350 KB decoded): around 400 MiB of memory at the most, only
/// ever used as much as you browse.
const coverMemoryCount = 1000;
const coverMemoryBytes = 400 * 1024 * 1024;

void configureImageCache([ImageCache? cache]) {
  final c = cache ?? PaintingBinding.instance.imageCache;
  c
    ..maximumSize = coverMemoryCount
    ..maximumSizeBytes = coverMemoryBytes;
}
