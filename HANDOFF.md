# Session handoff (2026-10-27)

What this session did and where things stand, for the next session to pick up. Read
[CLAUDE.md](CLAUDE.md), [PERFORMANCE_STATUS.md](PERFORMANCE_STATUS.md) and, on the
`perf/measure-cover-pipeline` branch, `PERF_MEASURE_COVER_PIPELINE.md` alongside this.

## Working agreement (unchanged)

- Small commits, pushed to `origin main`. `flutter analyze` clean and `flutter test` green before every commit
  (455 tests at the end of this session).
- Ask before adding packages. Don't refactor unrelated files.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `gh` is installed at `C:\Program Files\GitHub CLI\gh.exe` and authenticated (it may not be on the shell's PATH).
- The user's own Navidrome server credentials are never written to files or commits.

## Branches

- **main**: all fixes below.
- **perf/measure-cover-pipeline**: measurement-only logging (LIST swapped, downloadsWasted, bakedTwice, GATE,
  covers distinctIds), the run logs `tidewater_perf_A/B/C.log` (force-added; `*.log` is gitignored) and
  `PERF_MEASURE_COVER_PIPELINE.md`. It branched before the "12 downloads at once" change and has not been
  merged into main.

## The performance goal

60 fps minimum, 90–120 aimed for. Monitor: 32", 2560×1440, 144 Hz (fullscreen = about a 12×5 card grid).
Laptop: 13", 2560×1600, 180 Hz, weaker GPU. The user's library: ~518 albums, ~4,950 songs.

## Tooling built this session (profile builds only)

- `%TEMP%\tidewater_perf.log` (see [docs/perf-capture.md](docs/perf-capture.md)): a 3 s `FRAMES` summary, a
  `SLOW` line per slow frame (build/raster ms, cards built/pictured, stand-ins, covers shown/decoded/downloaded/
  dropped/held back, live vs pictured cards, image cache, scroll speed, how far the page moved and by what,
  memory, `RECOLORING`, the screen it happened on, ms since the last event).
- Automatic `NOTE` lines: PAGE, TAB, NOW PLAYING, IDLE, LYRICS, VISUALIZER, QUEUE, TRACK, RECOLOR, WINDOW, APP.
- Hotkeys: Ctrl+Alt+M mark; Ctrl+Alt+R marks a screen recording (badge with the log clock and a frame count,
  red/green border flash); Ctrl+Alt+1–0 toggle perf flags (ambient, aurora, shadows, smooth edges, covers,
  scroll-in, cover deferral, chrome, cards, sprites); Ctrl+Alt+T detailed timeline.
- To read a video: ffmpeg is at
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\yt-dlp.FFmpeg_...\bin\ffmpeg`. Find the badge in a frame to
  get the offset between video time and log `t=`, then pull frames at slow-frame times.
- Caches: `%LOCALAPPDATA%\dev.tidewater\tidewater\covers\<serverFolder>\` and `...\lists\<serverFolder>\`,
  where serverFolder = first 12 hex chars of sha1(server URL). Cold run = delete both (PowerShell
  `Remove-Item -Recurse -Force`).

## Fixes landed on main this session (in order)

1. Cards read the settled theme (`SettledTheme`) so a track-change recolor redraws them once, not every
   frame; drop targets only read the theme while dragged over.
2. Server answers over 64 KB decode on another isolate; the Now Playing cover prefetch no longer leaks.
3. Covers for cards already gone are dropped before reading/decoding (`CoverImage.hold/letGo`), and evicted
   from the image cache so they load normally later.
4. At most 24 cards built for the first time per frame; the rest show a stand-in (placeholder colors + plain
   title). While the page is "flying" (>40% of a screen in 25 ms) new cards stay stand-ins, skip the entrance
   animation and aren't pictured.
5. At most 8 newly decoded covers drawn per frame. Cards pictured 2 per frame (was 6); a card waits up to 0.4 s
   for its cover before its picture.
6. Drags/flings (trackpad) capped at 6,000 px/s; a far A–Z jump fades out, jumps, fades in.
7. Covers decode at their drawn width (32 px steps, `CoverImage.decodeWidth`); image cache up to 3000
   covers / 400 MB.
8. First-launch cover saving (`cover_precache.dart` + `cover_precache_view.dart`): saves every album and song
   cover (300 px) to disk, 10 workers, gate of 12; shows "Saving your covers…" with a filling squiggle
   whenever covers are missing (with a note on why the count exceeds the album count); "Keep browsing"
   shrinks it to a pill.
9. Docs: `PERFORMANCE_STATUS.md` (symptoms and causes), `flutter_architecture_map_claude.md` (scout report,
   untracked).

## What the measurements say (latest)

- Mouse wheel scrolling: fine. Sitting still: fine.
- Remaining cost: reading, decoding and drawing many distinct covers and cards (warm run C: 3 downloads but
  ~5,100 decodes, 440 slow frames on the laptop). The network matters only on a cold start.
- List swaps are cheap; double bakes and wasted downloads are small.
- **Duplicate cover ids:** Navidrome gives every song with embedded art its own cover id (`mf-…`), even when
  it is the album's picture: ~4,700 song cover ids for 518 albums. Tony's sample: 87 ids → 17 distinct images
  (~9× redundant decodes, memory and first-save downloads). The image cache fills its 400 MB cap.
- Each server URL keeps its own full cover cache (2 folders now: VPS 5,204 files / 275 MB, an old URL 383 files).

## Open items

1. **Issue #2** (https://github.com/JoshDoesStuff/tidewater/issues/2): replied. Promised next:
   - Add `PRECACHE total=<n> distinctBytes=<n>` (unique md5 of saved bytes) at the end of the cover save, on the
     measuring branch, to get the real duplicate ratio.
   - Open a separate issue for the **M → A letter rail bug** (clicking M jumps to A).
2. **Likely fix (not started, Josh's call):** content dedupe: map cover id → md5 of its bytes, decode and cache
   once per md5 (songs with truly unique art, e.g. the ADOFAI tracks, keep theirs). Josh chose NOT to switch songs
   to album covers. Also consider keying the cover cache by server identity instead of the URL.
3. Unconfirmed: first-time 40–100 ms spikes (likely shader compiles; whether Impeller actually runs on Windows is
   unknown).
4. Deferred features: M8 remainder (offline cache, extra Settings, real visualizer), later milestones per CLAUDE.md.
5. A WinUI 3 / Mica mockup exists (https://claude.ai/artifact/EfwBidBf8grR7g4vhV4KFw); Josh is staying on Flutter for now.

## Untracked files in the repo root (not committed on main)

`flutter_architecture_map_claude.md`, `devtools_options.yaml`, the run logs, `PERF_MEASURE_COVER_PIPELINE.md`
copy, older `tidewater_perf*.log` files.
