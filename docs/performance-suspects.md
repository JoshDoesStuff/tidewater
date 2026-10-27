# Performance: other things that might be costing frames

A scan of the codebase for anything that could cost UI-thread or GPU time, in rough order of how likely each is to
matter, with how to confirm. None of these is proven unless it says so. See `docs/performance-plan.md` for the
measurements, the tooling, and the main plan (the cover loading burst while fast-scrolling is the top suspect).

## A. Cover loading and drawing (top suspect, matches what Josh sees)

1. **No scroll awareness in image loading.** `CoverArt` always builds an `Image` for its cover as soon as the card
   is built, however fast the list is moving. Flutter's `Scrollable.recommendDeferredLoadingForContext` is unused.
   Check: fling through an unseen Artists list on the monitor; the `FRAMES` summary shows raster bursts (29 avg, p90
   57, max 96 were seen) and Josh sees placeholders then lag.
2. **Decoding at full size.** `CoverImage._load` (`lib/ui/widgets/cover_art.dart`) calls `decode(buffer)` with no
   target size: every grid cover is decoded at 300 px (about 360 KB) even when drawn at about 230 px, and the 150 px
   tiles (song rows) decode the 150 bucket only if the server bucket applies (see `CoverCache.bucket`). Use
   `ResizeImage`/`targetWidth`. Check: memory and the upload time for each new image.
3. **Unbounded concurrency.** `CoverCache.get` (`lib/core/api/cover_cache.dart`) starts a read and decode per card
   at once; `_inFlight` only de-duplicates identical keys. No queue, no priority, no cancel when a card is disposed
   (cards the user already flew past still decode). For uncached covers it also starts as many network fetches.
   Artist covers can need the server to fetch from an external image service, which is slow.
4. **Per-cover work on arrival:** an `AnimationController` for the fade (`CoverArt._fade`), a `Timer`
   (`_coverAfter`) that rebuilds to drop the placeholder, `setState` and a repaint, then (for cards) `onSettled` ->
   `MediaCard` `setState` -> bake. For 70 covers arriving together that is hundreds of objects and rebuilds in a
   few frames.
5. **First-use costs on the raster thread:** texture upload per new image; `FilterQuality.medium` (the `Image`
   default) generates mipmaps on first use (try `FilterQuality.low` on card covers); possible shader compilation
   jank on first appearance of an effect (Skia/ANGLE in profile mode). A DevTools raster trace tells these apart.
6. **Baking itself.** `MediaCard._bake` calls `OffsetLayer.toImageSync` once per card, a GPU render target each;
   if 20 to 40 cards bake in the same frame that is its own spike. It is not throttled and not deferred while
   scrolling (see the plan, step 1). Also each baked picture is about the card size times the pixel ratio squared
   (laptop at about 200 percent: roughly 1 MB each; 150 built cards: about 150 MB of graphics memory). Memory
   pressure on an integrated GPU could itself cause hitches. Check with DevTools memory, or lower
   `scrollCacheExtent` from 1400.
7. **`ImageCache` size** (`lib/app/image_cache_config.dart`): 1000 images, 400 MiB. Decoded covers evicted and then
   needed again are decoded again. Fine for now, relevant if (2) shrinks the images (the limits could then hold
   more).
8. **The placeholder painter** (`_PlaceholderPainter` in `cover_art.dart`) draws a gradient and 2 to 3 translucent
   shapes per card until the cover has fully arrived (and forever for covers that fail). Cheap, but 70 of them
   while the burst is on screen are not free. During a fast scroll a flat colour would do.

## B. Per-card cost and object count

9. **Objects per card.** Each `MediaCard` builds roughly: `StaggerIn` (AnimationController + Timer + GlobalKey),
   `MorphShape` (AnimationController.unbounded + ValueNotifier + a `Ticker` only while spinning),
   `CoverArt` (AnimationController + Timer), `Ripple` (Listener + Stack), `TweenAnimationBuilder`, `LayoutBuilder`,
   `MouseRegion` x2, `GestureDetector` x2 to 4, `Semantics` with a map of custom actions, `Hint`-free, two
   `LinkText`s (each `MouseRegion` + `GestureDetector` + `Text` + an `AppTheme.script` call that scans the string for
   CJK on every build). That is a lot of build and element work per card; at 144 to 180 Hz the UI thread budget is
   5.5 to 6.9 ms. Build avg is now 1 to 3 ms with a max of 44 to 68 ms in some frames (those are the spikes to
   chase on the Dart side: likely the burst in A).
   Possible reductions: one shared ticker for all fades, `const` and cached `Semantics` actions, a single
   `MouseRegion`, skipping `LinkText`'s hover state until the card is hovered (baked cards already skip them).
10. **`AppTheme.script`/`cjkScriptOf`** is called for every text build (card titles, song rows). Memoise per string.
11. **`StaggerIn` timers**: every card starts a `Timer` and a controller even for cards that will never be seen
    before being disposed. See the animation bug in the plan (step 5): starting on first visibility would also fix
    this cost.

## C. Frame pacing and always-on work

12. **Refresh rate.** The laptop is 180 Hz, the monitor 144 Hz. Anything that keeps the frame pipeline running every
    vsync costs even when nothing changes (the drifting background was doing this at 180 fps before it was moved
    to a 25 fps timer). Check idle: the `FRAMES` summary should show few or zero frames at idle. Candidates still
    running: `Visualizer` tickers (Now Playing, and the aurora behind pages while playing, capped 30/60 fps),
    `WavyScrubber` (mini player; a ticker while playing), `EqBadge`, `MiniEq`, `SquiggleLoader`, the morphing active
    card's spin `Ticker`, `LetterReveal`, Lottie rail icons, `Ripple`.
13. **Mini player and Now Playing while playing.** The mini player's `WavyScrubber` animates every frame while
    audio plays (it is on every page). It was never switched off in the bisect except through "mini player +
    shuffle button" (Ctrl+Alt+8), which showed no big change on Artists, but confirm on idle pages.
14. **Pointer move handler** in `AppShell` (`MouseRegion.onHover` sets `_pointer.value`) wakes a listener on every
    mouse event; the spotlight is now a moved layer so this is cheap, but check pointer-move frames.
15. **`PageFrame`/`SmoothScrollScope`** wraps every page in a `NotificationListener` and a primary controller; the
    glide ticks `forcePixels` + `didUpdateScrollPositionBy` per frame (cheap by design; verify with a trace).

## D. Pages and widgets not yet measured at all

16. **Home** (`lib/ui/pages/home_page.dart`): the hero cards use `ImageFiltered` blur, `Opacity`, `FittedBox` labels,
    `ShaderMask`-like scrims and `_Carousel` with an animated width; `ListView.separated` horizontal rows of
    `AlbumCard`. Never profiled with the new tools. Blur (`ImageFilter.blur`) over images is expensive on the GPU.
17. **Songs tab / Liked / playlists / Search** (`SongRow`, fixed extent lists of hundreds to thousands of rows):
    each row has `Pressable` + `AnimatedContainer` + `Ripple` + `CoverArt` (150 px) + `LinkText` x2 +
    `AnimatedOpacity` x2 + heart + `Draggable` wrapper + `Semantics` with actions. Rows are not baked. The
    Tracks/Albums excerpt showed raster 29 avg / p90 57 in one 3 s group (likely a first load or tab switch).
18. **Album, Artist, Genre and Playlist pages** use `SingleChildScrollView` with a `Wrap`/`Column` of everything
    (not lazy): an album with hundreds of tracks or an artist with 100 albums builds all of it at once.
19. **Now Playing:** the background `Visualizer` (aurora radial gradients, full-window `CustomPainter` at 60 fps),
    blurred lyric lines (`ImageFilter.blur` per line in `lyrics_list.dart`), the cover `MorphShape` with a spinning
    ticker, the queue panel's `BoxShadow` blur. Not part of the scroll complaint, but a likely cause of lag when it is
    open at fullscreen on the laptop.
20. **Window chrome:** `TitleBar`, `NavRail` (Lottie icons), `MiniPlayer` (blurred `BoxShadow` 24 px), the FAB's
    `BoxShadow`. Switching the mini player off did not help, but these draw on every frame of every scroll.

## E. Platform and engine

21. **Renderer.** Windows uses Skia over ANGLE (D3D11) unless Impeller is enabled. Try
    `flutter run -d windows --profile --enable-impeller` (step 3 of the plan). Also note which GPU each machine
    has (the monitor's PC and the laptop); the monitor showed worse numbers than the laptop in the same build at a
    lower resolution, which suggests a weaker or integrated GPU, a different driver, or the larger logical layout
    (the 32 inch at 100 percent scaling lays out more and bigger cards).
22. **Profile vs release.** The numbers are from `--profile`. Release is usually a little faster; do not assume.
23. **Debug-only code paths** that remain in profile builds: `PerfFlags` `ListenableBuilder`s in `MorphShape`,
    `CoverArt`, `LinkText`, `MediaCard` (cheap, but each is a listener per widget; remove or compile out of
    release if ever it shows up).
24. **Fonts.** Google Sans Flex (variable axes) plus bundled Noto Sans JP/SC fallbacks: the first time a glyph
    outside the primary font appears, the fallback font is loaded and shaped; artist/album names with CJK text can
    cause a hitch on first draw. Check by scrolling an unseen part of a library that has CJK names.

## How to hand this to someone else

* Start with `docs/performance-plan.md` (the data, the diagnosis, and the ordered plan).
* The first change to make is step 1 there (scroll-aware, bounded, right-sized cover loading, and throttled baking),
  because it matches both the measurements and what Josh sees. Measure with the `FRAMES` summary after each change
  and report the table (monitor and laptop, pictures on and off).
* Do not remove the per-card picture (`_bake`): it is what took the card cost from about 12 ms to a few ms.
