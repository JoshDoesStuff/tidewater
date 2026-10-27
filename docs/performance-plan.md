# Performance: where we are, what the numbers say, what to do next

Written so that a fresh session (or another model) can pick this up cold. Read `docs/dev-notes.md` and
`docs/milestones.md` first, then this, then `docs/performance-suspects.md` (every other thing that might be
costing frames, ranked, with how to check each).

## The goal

The user (Josh) needs scrolling to look smooth: **60 fps is the bare minimum, 90 to 120 is the target.**
Hardware, both run in `--profile`:

| Screen | Size | Refresh | Budget per frame |
|---|---|---|---|
| Monitor | 32 inch, 2560x1440 | 144 Hz | 6.9 ms (16.7 ms for the 60 fps floor) |
| Laptop | 13 inch, 2560x1600 | 180 Hz | 5.5 ms (16.7 ms for the floor) |

The laptop's pixel density is high (about 200 percent scaling), so everything is drawn at about twice the
logical size. The monitor is at 100 percent. The Library and Artists grids are up to 12 columns by 5 rows
visible at fullscreen (about 60 to 72 cards on screen, up to about 150 built).

## How to measure (all built in, profile builds only)

```
flutter run -d windows --profile
```

* `lib/app/frame_log.dart` prints, every 3 seconds that frames were drawn:
  `FRAMES 3s: 162 drawn, 41 over 16.7 ms | build avg 2.1 max 9.4 | raster avg 21.3 p90 30.2 max 41.0`.
  "build" is the Dart/UI thread (widgets, layout, recording paint), "raster" is the GPU thread. Compare the
  **raster avg and p90**. A frame count near 3 x refresh rate means the app is drawing every vsync.
* `lib/app/perf_flags.dart`: Ctrl+Alt+1 to 9 and 0 switch things off while the app runs:
  1 ambient shapes + spotlight, 2 aurora, 3 card shadows, 4 smooth card edges, 5 cover pictures, 6 card text,
  7 card clipping at all, 8 mini player + shuffle button, 9 the cards altogether, 0 "resting cards as one
  picture". Each press prints `PERF <name>: ON/OFF`. Everything is on by default and release builds ignore it.
* Josh pastes the terminal output into the chat (an attached terminal tab). The `mcp__terminal__read_terminal`
  tool can also read it.
* Remove or keep `PerfFlags`/`frame_log` before a release as you see fit; they are no-ops in release.

## What the data said, in order (all numbers are raster averages unless noted)

1. **Build side was the first problem.** `SliverLayoutBuilder` rebuilt every card on every scroll frame (build
   10 to 20 ms). Fixed with `SliverWidthBuilder` (`lib/ui/widgets/sliver_width_builder.dart`). Build is now
   1 to 5 ms.
2. **Raster side**, scrolling Artists at fullscreen: 13 to 17 ms. Switching off, one at a time, shadows, smooth
   edges, covers, text, ambient, aurora, clipping, the mini player: **none moved the number**. Switching off
   **all the cards** dropped it to 1.5 ms. So the cards cost about 12 ms per frame (about 0.17 ms each) and it
   is the sum of many small per-card drawing steps, not one of them.
3. **Fix: a resting card is drawn as one picture** (`MediaCard` in `lib/ui/pages/widgets/album_card.dart`,
   `_bake`, `_sprite`): the whole card (cover, clip, shadow, title, artist) is rendered once with
   `OffsetLayer.toImageSync` and shown as one `RawImage`. A hover (or press, active, or a loading cover) makes
   the real card again a frame later. Results (latest run, after also baking 150 ms after the cover settles and
   building 1400 px ahead):

   | Where | pictures on | pictures off |
   |---|---|---|
   | Laptop | 3.4 to 5.4 ms | 5.5 to 8.0 ms |
   | Monitor, cards already baked | 3 to 5 ms | 8 to 17 ms |
   | Monitor, scrolling into **new** rows | 7 to 13 ms, spikes of 30 to 100 ms | n/a |

4. **What is still bad (latest runs, Artists on the monitor, and Tracks/Albums):** while scrolling into cards that
   have not been seen yet, raster averages of 7 to 14 ms with p90 15 to 25 ms, and single groups of frames at
   **29 ms avg, p90 57, max 96** (a burst), plus `build max` of 44 to 68 ms in a few frames. When baked and idle
   the numbers are 3 to 5 ms (fine).
5. **Josh's observation, the key one:** *if I scroll fast I see the placeholder covers, and it lags like hell
   while it starts drawing the album covers.* That is the cover loading path (below), not the card drawing.

## Diagnosis (current best theory)

The remaining cost is **a burst when many covers arrive at once** while fast scrolling:

* each new card builds, shows a gradient placeholder (`_PlaceholderPainter`), asks `CoverImage` for its cover;
* `CoverCache.get` (`lib/core/api/cover_cache.dart`): `File.exists`, `readAsBytes`, `ImmutableBuffer.fromUint8List`
  (a copy), then `decode(buffer)` **at full size** (no target size): a 300 px JPEG/PNG is decoded for every card
  even when it will be drawn smaller or the same; the decode runs off the UI thread but the **texture upload
  happens on the raster thread at the first draw** of each new image, so a screenful arriving together is a
  raster spike;
* there is **no limit on concurrent requests**: dozens of file reads, decodes and (for uncached covers) network
  fetches start at once, and nothing prioritises what is on screen over what is merely in the cache extent or
  already scrolled past;
* each cover then runs its own `AnimationController` fade (`CoverArt._fade`) plus a timer that drops the
  placeholder (`_coverAfter`), so each arrival is also a rebuild and a repaint;
* only after that settles does the card get baked (`toImageSync`, a render-target per card, done in bursts too);
* images far behind the scroll are also decoded while the viewer is still flying past them.

Flutter has a built-in answer for the main case: `Scrollable.recommendDeferredLoadingForContext(context)` (true
when the scroll is moving too fast to be worth loading images). Nothing here uses it.

## The plan (in this order; measure after each step)

**Step 1. Make the cover pipeline cheap and scroll-aware (the highest-value change).**
* `CoverArt` (`lib/ui/widgets/cover_art.dart`): while `Scrollable.recommendDeferredLoadingForContext` is true, do
  not build the `Image` at all (show the placeholder), and ask for the cover once the scroll slows or stops
  (listen to the scroll position's `isScrollingNotifier` or re-check on `didChangeDependencies`). Do not start
  the fade for a cover that arrives while scrolling: show it at once (`_fade.value = 1`).
* Decode at the size it is drawn: use `ResizeImage` or pass `targetWidth` in `CoverImage._load` (bucketed to
  150 or 300, rounded up from logical size times device pixel ratio). Decoded memory and upload cost drop a lot
  for the 150 px tiles; keep 300 for grids and 800 for Now Playing.
* A small queue in front of `CoverCache.get`/the decode: at most about 4 file-reads/decodes at once, **newest
  request first** (LIFO), and drop a request whose card has since been disposed (cancel on dispose). Visible cards
  should win over cache-extent ones.
* Bake only when not scrolling (`pageScrolling` in `lib/ui/widgets/smooth_scroll.dart`, or the
  `isScrollingNotifier`) and at most 2 to 3 per frame, so baking never makes its own spike.
* While scrolling fast, draw a flat colour instead of the placeholder painter's gradient and shapes.
* Re-measure with the `FRAMES` lines. Target: raster avg under 6 ms and **no 29 ms groups** while flinging through
  an unseen library on both screens.

**Step 2. If a spike remains, get a real trace** (do not keep guessing). In `flutter run --profile`, open DevTools
(Performance tab), record while fast-scrolling, and look at the raster thread: expect either image upload,
`SkImage` mipmap generation (the `Image` widget defaults to `FilterQuality.medium`, which builds mipmaps on first
use; try `FilterQuality.low` on the card covers), `saveLayer`, or shader compilation. Shader compilation jank is
a real possibility on Skia/ANGLE in profile mode (first time each effect appears); check for it on the first scroll
versus later scrolls.

**Step 3. Try Impeller.** `flutter run -d windows --profile --enable-impeller` (check the Flutter version first;
Windows support is experimental in some versions). It removes shader-compilation jank and often makes
many-small-draws scenes cheaper. If it helps, say so before making it the default.

**Step 4. Profile the pages not measured yet** (see the suspects file): Home (blurred hero cards), the Songs tab
(thousands of `SongRow`s), Search, the Album page, Now Playing with lyrics and the aurora, the queue panel.

**Step 5. The animation bug Josh noted (not performance, but easy to fix once the above is stable).** After the
first screenful of cards, **later rows never animate in** (also true of albums, tracks, etc.). Cause, almost
certainly: `StaggerIn` (`lib/ui/widgets/effects/stagger_in.dart`) starts its fade from `didChangeDependencies`
when the card is *built*, but grids now build **1400 px ahead** (`scrollCacheExtent` in `artists_page`,
`library_page`, `liked_page`, `lists_page`; it was 700 px before, which already did this), so the fade plays
**off screen** and is finished before the card scrolls into view. There is also no exit animation at all.
Fix: start the entrance when the card first becomes visible in the viewport (check the card's position against
the viewport on each frame until it is visible once, e.g. via `RenderAbstractViewport.of(context)` /
`getOffsetToReveal`, or a tiny visibility detector based on `SliverGrid` child paint offsets), then run the same
fade. Keep the cheap path (no Opacity or Transform once settled; the `GlobalKey` trick is already there).
Remember that a card is now a baked picture at rest; the fade is applied outside it, so the two work together.

## What was already done (so nobody repeats it), newest last

* Smooth wheel scrolling (`lib/ui/widgets/smooth_scroll.dart`, a critically damped glide on every page via
  `PageFrame`). One start/end notification per glide.
* `SliverWidthBuilder` instead of `SliverLayoutBuilder` (no rebuild of the grid on every scroll frame).
* Cards ignore hover while the page scrolls (`MediaCard._isScrolling`).
* Resting cards at 2D transforms only; the perspective matrix only while tilting; no Transform/Opacity wrappers
  once settled (`StaggerIn` and the card both use a `GlobalKey` so the subtree is not rebuilt when a wrapper is
  removed).
* Cheap resting shadow (rounded-rectangle blur instead of a path blur) in `MorphShape`.
* Ambient background: blobs drawn once and moved by the compositor; drift driven by a 25 fps timer (not the
  screen refresh); aurora behind pages at 30 fps; both left undrawn once a page has been scrolling for 250 ms
  and restored 450 ms after it stops; spotlight is one small moved picture.
* Hover play button only built while hovering; `_hoverMorph` makes the spring play after the live card is built.
* Resting card as one picture (`_bake`), 150 ms after the cover settles; grids build 1400 px ahead.
* Accessibility: `Hint` instead of `Tooltip`, one node per row/card (see `docs/dev-notes.md`).

## Constraints and traps (learned the hard way)

* Do not add packages without asking Josh (CLAUDE.md). Commits: small, `flutter analyze` clean and `flutter test`
  passing first, message ends with the Co-Authored-By line from the session instructions, push to `origin main`.
* Tests: `pumpApp` turns card pictures **off** (`PerfFlags.instance.sprites = false` in `test/support/pump.dart`)
  because the card text is not in the tree when baked; `test/ui/card_sprite_test.dart` turns it on.
* `dart format` on a file can reformat all of it (large diffs, and it removes braces from one-line `if`s that the
  analyzer then flags). Prefer targeted edits.
* On this Windows shell, `perl -0pi -e` with `\x27` for quotes works; heredocs containing apostrophes in `bash`
  commands break. Use the Write/Edit tools for Dart with apostrophes. Python is not installed.
* Running the full suite: `timeout 540 flutter test`. A test that waits on a timer without pumping can hang
  (`taskkill //F //IM flutter_tester.exe`).
* The `SLOW FRAME` per-frame lines were replaced by the 3 s summary; do not go back to line-per-frame (the logs
  were enormous).
* The simulated frame costs in widget tests (debug JIT) are not representative; only `--profile` numbers count.

## Step 1, done (Opus)

* The wheel glide now runs as a real scroll activity (`_GlideActivity`) that reports its speed, and the app's scroll
  physics (`DeferringScrollPhysics`, set in `app.dart`) call anything above 1400 logical px/s "too fast". Flutter's
  `Image` already wraps every provider in `ScrollAwareImageProvider`, which holds back covers that are not in memory
  while that is true. Before this the glide's activity was idle (speed 0), so covers were loaded for every card flown
  past.
* `CoverCache` lets at most 6 reads/downloads run at once, newest request first (`_Gate`).
* Covers that arrive while the page is scrolling appear without a fade; card covers use `FilterQuality.low` (no
  mipmap pass per new cover).
* Card pictures are made at most 3 per frame (`_BakeQueue` in `album_card.dart`).
* Not done from step 1: decoding at the drawn size (little gain for the 300 px grid covers on these screens; worth it
  for 44 px song-row covers later), cancel-on-dispose, and a flat placeholder while scrolling. Measure first.

## Step 5, done (Opus)

* `StaggerIn` now waits until its item is on screen (it listens to the scroll position and checks the item's rect
  against the scrollable's once each frame is laid out). Items on screen at page load run the diagonal wave as
  before; items scrolled into view later animate at once (fade, 14 px rise, slight scale). Items built ahead of the
  scroll no longer play their entrance off screen, and no longer start a timer they may never need.
  Test: `test/ui/stagger_on_view_test.dart`. There is still no exit animation (cards leaving the window are simply
  scrolled away, and disposed once past the cache extent).

## After steps 1 and 5: worse (run 2026-10-26, monitor, Artists/Library fast scrolling)

Raster avg rose to 15 to 30 ms (p90 25 to 42, max ~100). Two likely reasons, both from step 5's `StaggerIn` change:

* Cards built ahead of the scroll waited at **opacity 0**, which is never painted, so they could not be baked into
  their resting picture (baking copies the painted layer). Every card arrived on screen live and stayed live while
  it animated. Fix: a waiting card is drawn plainly (it is off screen anyway), so it bakes early.
* A row scrolling in faded with an `Opacity` over a live card: an offscreen pass per card per frame, a dozen at a
  time. Fix: scrolled-in rows rise and scale only (a transform, no opacity). The page-load wave keeps its fade.

Two switches replaced ones that had answered their question: Ctrl+Alt+6 now turns the scroll-in animation off,
Ctrl+Alt+7 turns off holding covers back while scrolling fast (`DeferringScrollPhysics`). Next run: baseline, then
each of those, to see whether either is still costly.

## Run after that (monitor): what each switch did

* Baseline: good stretches (4 to 6 ms) but sustained blocks of 28 to 30 ms avg while scrolling into unseen rows.
* Scroll-in animation off: blocks shrank to 9 to 17 ms. (Its cost was mostly that cards were still live.)
* **Holding covers back off: mostly 3.5 to 5 ms for a long stretch**, one bad block at the end. Holding covers back
  kept cards waiting for their cover, so not pictured, so live and expensive. It is now **off by default**
  (`PerfFlags.deferCovers`, Ctrl+Alt+7 turns it on for comparison).

Changes from this: a card is pictured soon after it is built even if its cover has not arrived (the picture shows
the placeholder); it keeps fetching the cover through an `ImageStream` (`_preloadCover`) and is pictured again once
the cover is in (`_coverReady` is part of the picture's "look"). The 4 s give-up timer is gone. Pictures are made up
to 6 per frame (was 3).
