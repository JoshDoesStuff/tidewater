import 'package:flutter/painting.dart';

/// How many decoded covers stay in memory. The Flutter default is 1000 pictures
/// but only 100 MiB, so scrolling back through a big Library decoded covers
/// again. Grid covers are decoded at the size they are drawn (about 190 px on a
/// full-screen grid, ~150 KB), so about 2800 fit in the same 400 MiB (a
/// 5000-song Library kept only 1000 and decoded the rest again on the way back);
/// only ever used as much as you browse.
const coverMemoryCount = 3000;
const coverMemoryBytes = 400 * 1024 * 1024;

void configureImageCache([ImageCache? cache]) {
  final c = cache ?? PaintingBinding.instance.imageCache;
  c
    ..maximumSize = coverMemoryCount
    ..maximumSizeBytes = coverMemoryBytes;
}
