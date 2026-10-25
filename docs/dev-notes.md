# Dev notes (for future Claude sessions)

Hard-won lessons from building milestone 1 + demo parity. Read this and `milestones.md` before touching UI or
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
| What screens look like | `flutter test tool/render_shots_test.dart` then read `build/shots/*.png` |
| Frame times per scenario | `flutter run -d windows --profile -t tool/perf_main.dart` |
| Letter/text smoothness in px | `flutter run -d windows --profile -t tool/letter_probe_main.dart` |
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
- Playback audio, the visualizer levels and lyrics are **simulated/fake** until M3/M7; say so in UI/docs, never fake silently.

## Don't

- Don't reintroduce `Opacity`/per-letter `Text` for animated titles, `AnimatedScale` on lyric text, or `Cubic`.
- Don't use debug-mode feel to judge smoothness, or centroid-only metrics (they hid shimmer and curve noise).
- Don't assume a milestone's UI is "done" because it renders: check the demo list in `CLAUDE.md` and the stand-in
  table in `milestones.md`.
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
  `HttpOverrides.global = null` (see `tool/real_covers_test.dart`).
- **Server tools** (all read-only): `dart run tool/server_check.dart <url> <user> <pass>` (or `--api-key`),
  `flutter test tool/real_covers_test.dart` (env `TIDEWATER_URL/USER/PASS/ALBUMS`; defaults to the public demo,
  `demo`/`demo`), `flutter run -d windows -t tool/session_probe_main.dart` (secure storage round trip).
- **Dart trap that bit once**: `Future.microtask(() => map.remove(key))` *returns the removed future*, so a failed
  download re-raised its error as unhandled. Use a block body (`scheduleMicrotask(() { map.remove(key); })`).
- **Windows shell**: this machine has no Python; `flutter test --name=word` (a name with spaces breaks
  `flutter.bat`); in the Bash tool a heredoc containing apostrophes can fail, so write such files with the Write tool.
- **Known pre-existing hitch**: opening Now Playing has 2-3 frames over 33 ms (max ~50 ms) in the profile run. M1 has
  the same numbers (checked at `f978439`), so it is not a regression; candidates: first build of the overlay plus
  the flight. Worth a look in M6.
- **Servers**: a typed address with no scheme is tried as https then http; "Trust this server" accepts only that
  host's certificate. Navidrome ignores articles when sorting ("The Beatles" under B); the A–Z rail mimics that.
