# Dev notes (for future Claude sessions)

Hard-won lessons from building milestone 1 + demo parity. Read this and `milestones.md` (same folder) before touching UI or
animation. `CLAUDE.md` is still the source of truth for design; this file is *how to work here* and *what not to redo*.

## How the user works with me

- `docs/tidewater-m3e-demo.html` is the reference. When they say "make it match the HTML", **port the JS/CSS
  literally** (same durations, curves, anchors, class rules), don't re-interpret. Every time I improvised, it felt
  off.
- They test by running the app and send screenshots (`screenshots/`) or describe a specific interaction. Ask which
  screen / direction (entering vs leaving) if a report is vague.
- Keep summaries short and concrete; say plainly what I could and couldn't verify. They notice polish at the
  sub-pixel level (jitter, pops, cut-off labels).
- Commit in small, reviewable steps with the `Co-Authored-By` trailer. Ask before adding packages not listed in
  `CLAUDE.md` (so far added from the list: riverpod, go_router, window_manager, shared_preferences).
- Don't refactor unrelated files. Stop after a milestone and let them run it.

## Verifying work (I can't see the real window)

The desktop is often locked, so screen capture of the real app returns the lock screen. Use the tools instead:

| Need | Command |
|------|---------|
| Static check | `flutter analyze` (must be clean) and `flutter test` (must pass) |
| What screens look like | `flutter test tool/probes/render_shots_test.dart` then read `build/shots/*.png` |
| Frame times per scenario | `flutter run -d windows --profile -t tool/perf/perf_main.dart` |
| Letter/text smoothness in px | `flutter run -d windows --profile -t tool/probes/letter_probe_main.dart` |
| Console errors | run the app and count lines (AXTree errors were 837 per launch before the fix; now 0) |

- Measure in `--profile`. Debug builds are several times slower and make animations look janky; profile baseline is
  build ≈ 1 ms, raster ≈ 3-8 ms. Budget: no frame > 33 ms in any scenario.
- Run long probes with `Start-Process ... -RedirectStandardOutput` and `WaitForExit(ms)` so they can't hang the
  shell. Don't kill `flutter`/`dart` mid-build: it leaves a half-written build ("Can't load AOT data"); do a clean
  `flutter build windows --debug` then `flutter run --no-build`.
- Test font is Ahem (very wide): wide labels overflow in tests but not in the real app. Make rows wrap/flex anyway.
- Widget tests: advance time in 100 ms steps (`_advance`), a single `pump(2s)` only builds a new route and doesn't run
  its animation. Dispose `SemanticsHandle`s inside the test body. Tests that play audio must stop playback and
  `pumpWidget(SizedBox())` at the end (pending-timer check). `DateTime.now()` isn't faked: count timer ticks.
- Hover in tests: `FocusableActionDetector`'s hover callback depends on focus-highlight mode; use `MouseRegion`.
- Git on Windows prints "LF will be replaced by CRLF" for every file: harmless, and makes the shell exit 255.
- PowerShell: no `&&`; double-quoted strings don't process `\n` (use here-strings / backtick-n); `Select-String`
  has no `-Recurse` (use the Grep tool).

## Animation rules (all measured in the real engine, Impeller/GLES)

1. **Animated text is a texture.** Re-drawing glyph outlines every frame at fractional positions shimmers, even with
   exact positions. Use `GlyphRun` (one atlas, one `drawRawAtlas`) for titles and `LyricsList` for lyrics. Per-glyph
   `drawImageRect` + color filter stalls the GPU (off-screen pass per glyph); do not do that.
2. **Easing: use `PreciseCubic` (all `Motion` curves).** Flutter's `Cubic` has a 0.001 bisection tolerance: up to
   0.17 px of per-frame noise on a 58 px title.
3. **Never round animated transforms to whole pixels** (≈10× more jitter).
4. **Never swap widget structure mid-animation** (e.g. a blur wrapper that appears/disappears): it recreates implicit
   animation state and the value snaps. Use `ImageFiltered(enabled:)` or keep structure fixed. Never swap an
   animating widget for a transform-free one at the end either (landing pop).
5. **Port CSS transitions literally** (`lyrics_motion.dart`): per-property duration/curve, retarget from the value
   currently shown, fixed anchors instead of measuring layout. CSS's default curve is `ease`
   (`Motion.cssEase`) when the demo names none.
6. **Exits are quick, entrances springy.** Anything that disappears when the pointer moves elsewhere (hover play
   buttons) must fade in ≈150 ms, or it lingers over the next card.
7. **Hide animating text from semantics** behind one stable label (`ExcludeSemantics` + `Semantics(label:)`); per-letter
   nodes made the accessibility tree rebuild every frame (hundreds of `AXTree` errors, plus jank). Also exclude
   decorative layers (ambient, visualizer, wash).
8. Wavy progress: sample the sine finely and always end the path exactly at the handle; interpolate the position
   per frame between the engine's ~30 Hz reports (never let a late report move the bar backwards).
9. Shapes: lobe tips (`base × (1 + amp)`) can exceed 1 and get sliced by the box; `morphPath` already shrinks them
   to fit. Keep it that way for new shapes.
10. Honor reduced motion everywhere (`Motion.of`, `Motion.curve`, no spin/overshoot/wash/letter motion).

## Code map and gotchas

- `core/` has no Flutter UI imports. `PlaybackEngine` is the only playback API; today `SimulatedEngine` (clock only).
- Providers: `app/providers/` (settings, playback, ui). Positions come from `positionProvider` (a `ValueNotifier`) so
  progress bars repaint without rebuilding.
- The scheme is generated from the playing album and animated app-wide in `app.dart` (rebuilds the themed tree each
  frame for 800 ms; fine so far). Seeded from the playing cover's pixels (`core/color/cover_seed.dart`).
- Everything is keyed by server **id** (albums, tracks, covers). The engine takes a queue; `PlaybackState.track` is null until something is queued, and the mini player is hidden then.
- Now Playing is a 1280×800 design canvas inside a `FittedBox`; backdrop and visualizer fill the real window.
  Glyph pixel-alignment is skipped under a non-1 scale (no grid to hit).
- Letters: `LetterReveal` (every page-title build) and `LetterSwap` (Now Playing title; speed from Settings).
- Settings persisted: reduce motion, dark/light, visualizer style, track-change speed.
- Keyboard: global handler in `app_shell.dart` (Space, N, P, L, V, Esc); ignored while an `EditableText` has focus.
  Known gap: Space can also activate a focused button.
- Playback audio, the visualizer levels and lyrics are **simulated/fake** until M3/M8; say so in UI/docs, never fake silently.

## Don't

- Don't reintroduce `Opacity`/per-letter `Text` for animated titles, `AnimatedScale` on lyric text, or `Cubic`.
- Don't use debug-mode feel to judge smoothness, or centroid-only metrics (they hid shimmer and curve noise).
- Don't assume a milestone's UI is "done" because it renders: check the demo list in `CLAUDE.md` and the stand-in
  table in `milestones.md` (same folder).
- Don't add the removed badge shapes next to "Good evening" / "Library" (CLAUDE.md #16).
- Don't leave probe/perf processes running (`Get-Process tidewater,flutter,dart | Stop-Process`).

## Server, data and tests (added in M2)

- **Layers**: `core/api/` (client, `connect()`, cover cache, session store; no Flutter UI imports) → `app/providers/`
  (session, library, cover, scheme, playback) → `ui/`. The UI only sees `LibraryApi` (an interface), so tests swap in
  `test/support/fake_library.dart`.
- **Test harness**: `test/support/pump.dart` (`pumpApp`, `advance`, `disposeApp`) boots the whole app on the fake server
  (`testOverrides` in `test_app.dart`). Always `ProviderScope(retry: (_, _) => null)`: Riverpod 3 retries failed
  providers on its own, which hides error states and leaves timers pending.
- **Covers in widget tests**: the real `CoverCache` does file IO, which never completes under fake async (it looks
  like "the scheme never changes"). Tests override `coverCacheProvider` with `NoCovers`; the cache itself has plain
  `test()`s with a temp folder.
- **Real network**: `flutter test` blocks HTTP (everything answers 400). For a real-server test set
  `HttpOverrides.global = null` (see `tool/probes/real_covers_test.dart`).
- **Server tools** (all read-only): `dart run tool/probes/server_check.dart <url> <user> <pass>` (or `--api-key`),
  `flutter test tool/probes/real_covers_test.dart` (env `TIDEWATER_URL/USER/PASS/ALBUMS`; defaults to the public demo,
  `demo`/`demo`), `flutter run -d windows -t tool/probes/session_probe_main.dart` (secure storage round trip).
- **Dart trap that bit once**: `Future.microtask(() => map.remove(key))` *returns the removed future*, so a failed
  download re-raised its error as unhandled. Use a block body (`scheduleMicrotask(() { map.remove(key); })`).
- **Windows shell**: this machine has no Python; `flutter test --name=word` (a name with spaces breaks
  `flutter.bat`); in the Bash tool a heredoc containing apostrophes can fail, so write such files with the Write tool.
- **Known pre-existing hitch**: opening Now Playing has 2-3 frames over 33 ms (max ~50 ms) in the profile run. M1 has
  the same numbers (checked at `f978439`), so it is not a regression; candidates: first build of the overlay plus
  the flight. Worth a look in M7.
- **Servers**: a typed address with no scheme is tried as https then http; "Trust this server" accepts only that
  host's certificate. Navidrome ignores articles when sorting ("The Beatles" under B); the A–Z rail mimics that.

## Playback, SMTC and measuring (added in M3)

- **Build requirements**: Flutter, Visual Studio C++ workload, and **Rust** (`rustup`; `smtc_windows` compiles a Rust
  library). A shell opened before Rust was installed does not have it: use
  `$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")`
  (PowerShell) or add `~/.cargo/bin` (Git Bash). `flutter_rust_bridge` is pinned to 2.11.1 in `dependency_overrides`;
  without the pin the app logs "codegen version should be the same as runtime" and runs without media keys.
- **Layers**: `core/playback/` (`PlayQueue`, `QueueEngine`, `AudioBackend`, `ScrobbleTracker`, `SavedSession`; pure Dart,
  fully unit-tested) -> `app/playback/` (`MediaKitBackend`, `SmtcControls`: the only files that touch media_kit and
  smtc_windows) -> providers. Tests and tools use `SimulatedEngine` (the same `QueueEngine` on a clock backend).
  `testOverrides` gives the simulated engine a 1 hour tick, because its clock is a real `Stopwatch` that fake time does
  not advance: set positions in tests with `container.read(positionProvider).value = ...`.
- **Things that need the real thing**, each with a tool that prints `PROBE ok/FAIL`:
  `tool/probes/engine_probe_main.dart` (audio; audible but quiet), `tool/probes/smtc_probe_main.dart` + `tool/probes/smtc_check.ps1`
  (reads the Windows media session back through the WinRT API in PowerShell and presses its buttons),
  `tool/probes/e2e_main.dart` + `tool/probes/e2e_check.ps1` (the whole app), `tool/probes/session_probe_main.dart` (secure storage),
  `tool/probes/server_check.dart` (the API). Run app-style tools with `Start-Process flutter.bat ... -RedirectStandardOutput`
  and `WaitForExit`; `flutter run` needs `--no-pub` and the cargo PATH.
- **libmpv/media_kit quirks** are listed in the M3 wrap-up in `milestones.md` (same folder); the ones that bite: its `completed` fires
  per file, its `playing` blinks at every track change, positions can be negative, and it skips a failing file itself.
  Never trust one event to mean one thing; check what is actually happening (is audio advancing?).
- **Windows media overlay**: cover must be an `https://` URL; `file://` is silently ignored. The overlay counts time by
  itself while playing, so only send the timeline on a seek or track change.
- **Perf measuring rules**: use `tool/perf/run_perf_real.ps1 -Only "scroll,np" -Url ... -User ... -Pass ...` and compare to the
  `startup` phase of the same run (the GPU is shared; other apps make everything 1.5-3x slower). Bisect by
  *removing things*, one at a time, and measuring: guessing (shadows? clip path? transform? RepaintBoundary?) was wrong
  five times in a row; the culprit was a gradient painted under every image. Raster-bound phases are about what is
  *drawn*, build-bound ones about what is *rebuilt*.
- **Shell habits that cost time**: `git commit` after `;` ignores a failed `flutter analyze` (use `&&`); blind
  `sed 'N,Md'` line-range edits mangled three files (re-read the lines first, or use the Edit tool); a heredoc with
  apostrophes can fail in the Bash tool (use the Write tool); `flutter test --name=word` (no spaces).
- **Never use Material's `Slider` here**: with it on screen Windows' accessibility tree failed on every update
  ("Failed to update ui::AXTree ... will not be in the tree", hundreds of lines, even after leaving the page). Found by
  running the real app (`tool/probes/e2e_main.dart --dart-define=TW_GO=/settings,/home,...` navigates and the console is
  counted) and removing page parts one per run. Settings uses a plain custom slider plus one explicit semantics node,
  like the volume slider. Widget tests cannot see this class of bug; check a new control type in the real app.

## Animated icons (M5)

- New icon animation = a `GlyphKind` in `ui/widgets/animated_glyphs.dart` (a painter case, 24 x 24 box, 2 px round
  stroke), then use `AnimatedGlyph` or `glyphFor(kind)` as an `ExpressiveIconButton.glyph`. It plays on the rising
  edge of `active` (press) or `hovered`. Reduced motion skips the play.
- Traced-on icons erase and redraw (`_redraw`); `_ghost` keeps a faint copy when the Settings option is on.
- Lottie files: tint with a `ColorFiltered` (srcATop), not `ValueDelegate` color overrides (these files have unnamed
  shapes, so key paths crash). Remove any white "knockout" layers from a file before tinting.
- Text drawn from textures (`GlyphRun`, lyrics) is baked at pixel ratio times the scale applied above it
  (`FitScale`) and pixel-snapped through that scale. Without that it looks soft once the Now Playing canvas is
  stretched to the window (seen on a 100 % monitor after a 200 % laptop panel).
- Stack children that appear and disappear (scrims, popups) need keys, or siblings shift and implicit animations
  restart from their end state (the queue popup "just appeared" because of this).
- Gate commits on the tests (`flutter test` first), not only on `grep` of its output.

## App icon

`tool/branding/app_icon.dart` defines the icon designs once (SVG text and Canvas drawing share the geometry; both designs
are flat, no gradients). Regenerate `assets/branding/tidewater_<design>.svg` / `.png` (cookie, record) and
`windows/runner/resources/app_icon.ico` (from `windowsDesign` in the render test) with
`flutter test tool/branding/render_app_icon_test.dart`, then rebuild the Windows app (Windows caches icons; a new .ico may
need the exe renamed or the icon cache cleared before the taskbar updates).
