# Performance status

Where Tidewater's performance stands as of 2026-10-27: what still goes wrong, what you see when it
does, and what the measurements say. Based on the profile log (`%TEMP%\tidewater_perf.log`, see
[docs/perf-capture.md](docs/perf-capture.md)) and a screen recording synced to it with Ctrl+Alt+R.

Target: 60 fps minimum, 90–120 fps aimed for, on a 2560×1440 144 Hz monitor (fullscreen, a 12×5
card grid) and a 2560×1600 180 Hz laptop. "Build" below is the app's own work per frame (widgets,
layout, recording what to draw); "raster" is the graphics thread drawing it.

## What is fine now

- **Mouse wheel scrolling** on Songs, Albums and Artists, even through the 5,000-song list:
  long stretches with zero slow frames, raster 3–4 ms.
- **Sitting still** on any page: 2–3 ms per frame.
- **Track change recolor**: used to rebuild every card on every frame for most of a second
  (30–65 ms frames); cards now redraw once.

## What still goes wrong

### 1. The fill-in after a big change of screen

**When:** after a far letter jump in the A–Z rail, switching tabs (Songs, Albums, Artists),
opening Library or Artists, and right after a track change.

**Symptoms:** the grid fades back in as plain placeholder tiles (gradients with the title), then
the covers trickle in over roughly half a second while the app stutters. In the recording a jump
shows a blank page, then placeholders, then covers popping in a few at a time.

**What the log says:** 35–107 ms raster frames in that half second, often with nothing else going
on: no scrolling, no new cards, only

- cards being turned into their resting pictures (each card drawn once more into an image on the
  graphics thread), six per frame, and each card twice (before and after its cover arrived);
- many covers being drawn for the first time in the same frames (up to 125 decoded in one batch,
  hundreds held back by the per-frame limit).

**Latest change (not yet measured):** two pictures per frame instead of six, a card waits for its
cover (up to 1.2 s) before its picture, at most 8 new covers drawn per frame. Expect smoother but
slightly slower fill-in.

### 2. Trackpad scrolling (much better, not solved)

**Symptoms:** a trackpad fling felt far worse than the mouse wheel: heavy stutter, blank or
placeholder tiles flashing past.

**What the log says:** the trackpad moved the page 1,000–3,700 px in a single frame, so nearly
every card on screen was brand new every frame (about 200 cards at fullscreen). Those frames took
30–80 ms to draw. Turning features off one at a time (covers, shadows, smooth card edges, card
pictures, the scroll-in animation) made **no difference**: the cost is the sheer number of new
cards per frame, not any one effect.

**Current mitigations:** drags and flings are capped at 6,000 px/s (a little above the mouse
wheel); while the page moves faster than 40% of a screen per 25 ms, new cards stay cheap
stand-ins, skip their entrance animation and are not pictured.

### 3. First-time spikes

**Symptoms:** single hitches the first time something is shown: app start, the first visit to a
page, the first time Now Playing opens.

**What the log says:** one 40–100 ms raster frame with no activity at all (the worst seen was
101 ms on opening Now Playing). The pattern matches the graphics engine preparing (compiling) a
drawing effect the first time it is used. Not confirmed: a DevTools trace runs out of memory, and
an Impeller run (the newer engine, which prepares effects ahead of time) looked the same, so it is
unclear whether Impeller was actually active.

### 4. Building a full screen of cards at once

**Symptoms:** a short blank or half-drawn moment when a grid page opens.

**What the log says:** opening a grid page built 132 cards in one frame (35–56 ms build). Now at
most 24 cards are built per frame, the rest show a stand-in for a frame or two; first-frame builds
are down to roughly 30–45 ms but still over budget at fullscreen.

## Fixed along the way (for context)

- Covers for cards already scrolled past were still read and decoded (up to 750 in one burst,
  +140 MB memory): such loads are now dropped.
- Server answers over 64 KB (song list pages) are decoded off the main thread.
- The Now Playing cover prefetch kept every cover it warmed for the whole session.

## What would help next

- A screen recording plus log of the latest build (Ctrl+Alt+R), with a few letter jumps, a tab
  switch and a track change, to see whether the fill-in is now smooth.
- Confirming whether Impeller really runs on Windows (`flutter run -d windows --profile
  --enable-impeller`, then look for an Impeller line in the startup output), to settle the
  first-time spikes.
- If the fill-in stays heavy: draw grid cards more simply (no per-card picture, a cheaper shadow)
  or decode covers at the size they are drawn, to cut the graphics work per new card.
