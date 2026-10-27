# Cover pipeline measurements (2026-10-27)

Measurement only, no fixes. Laptop, profile build, window 2560×1552 at 100% scale. Logs are next to this
file: `tidewater_perf_A.log`, `tidewater_perf_B.log`, `tidewater_perf_C.log`.

| Run | Server | Cache |
|---|---|---|
| A | demo.navidrome.org | cold (covers and saved lists deleted) |
| B | Josh's VPS URL | cold |
| C | Josh's VPS URL | warm (relaunched after B, nothing deleted) |

(The planned ngrok and LAN runs were dropped: ngrok is no longer used.)

## How the runs went

- **A:** the demo library is small (no A/M/Z letters to jump between, not enough albums to fling), so the
  order was: sit on Albums, Songs tab, scroll down, letter jumps, close.
- **B and C:** the planned steps (Albums hands off, letter jumps, fling, Songs fling and hands off), except
  the A > M > Z letter jumps were done on the Songs tab only. In B the app sat for about 8 minutes before
  the steps (APP inactive/resumed lines), while the first-launch cover saving downloaded the whole library.
- **C:** Ctrl+Alt+M was missed for some steps, so its marks do not line up with the steps. C was also run on
  a build **without** the new measurement lines (no GATE, LIST, distinctIds, downloadsWasted or bakedTwice
  in its log), so those columns are blank for C.
- Noticed in passing: clicking **M** in the letter rail takes you to **A**. Not investigated yet.

## Results

| | A demo, cold | B VPS, cold | C VPS, warm |
|---|---|---|---|
| First screen of covers in (≈60 covers shown after opening Library) | ~1.9 s | ~8.3 s | ~1.5 s |
| SLOW frames (over 10 ms on either thread) | 177 | 567 | 504 |
| Worst raster | 74.6 ms | 136.1 ms | 108.5 ms |
| Worst build | 33.3 ms | 57.5 ms | 56.3 ms |
| Downloads | 545 | 5,199 | 2 |
| Disk reads | 572 | 5,658 | 5,512 |
| Decodes | 591 | 5,714 | 5,515 |
| Songs tab distinct cover ids (max) | 481 | 4,677 | n/a |
| downloadsWasted | 0 | 1 | n/a |
| bakedTwice | 80 | 162 | n/a |
| Max GATE waiting | 74 | 141 | n/a |
| imageCache at end | 591 (115 MB) | 2,718 (400 MB) | 2,721 (400 MB) |
| SLOW frames within 1 s of a `LIST … swapped` | no swap logged | no swap logged | n/a |

Notes on the numbers:

- **No `LIST swapped` lines:** A and B started with no saved lists, so nothing was swapped (the lists
  loaded fresh). C would have swapped, but its build had no LIST line. So whether a list swap causes slow
  frames is still unmeasured: it needs a warm run on the measuring build.
- **B's downloads include the first-launch cover saving** (all ~5,100 covers), not only what was on screen.
  It also competed with the screen for the download queue, which is likely most of B's 8 s first screen and
  its long GATE queue (up to 141 waiting).
- **C (warm) downloaded almost nothing** (2) but still read and decoded ~5,500 covers from disk: the cache
  saves the network, not the decoding. It still had 504 slow frames and a 108 ms worst raster, close to B,
  so on this laptop the slow frames are not mostly about downloads.
- **imageCache hit its 400 MB ceiling** in B and C (about 2,700 covers held): scrolling the whole Songs tab
  fills it, and the oldest covers are decoded again if you scroll back.
- **bakedTwice is small next to the decodes** (80 / 162): cards pictured a second time because the cover
  came late are not a big share of the work.
- **downloadsWasted ≈ 0:** dropping loads for cards that scrolled away works; finished downloads are almost
  never thrown away.
- The "first screen" time is an estimate: covers shown are counted in 3-second windows, so it is only
  accurate to a second or two.

## What this suggests (not acted on)

- Warm or cold, the laptop's slow frames come from decoding and drawing covers and cards, not from the
  network.
- A warm run on the measuring build (with Ctrl+Alt+M at each step) is still needed for the LIST swap
  question and for per-step numbers.
