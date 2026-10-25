# Tidewater handoff
- CLAUDE.md: Flutter + Material 3 Expressive guide (primary).
- milestones.md: working plan — what is done, what is simulated, and what each remaining milestone must cover.
- docs/tidewater-m3e-demo.html: interactive reference (open in a browser).
- docs/mockups/tidewater-m3e-*.svg: M3E static layouts. tidewater-1..7: older WinUI/Mica mockups.
- docs/tidewater-motion-demo.html + docs/CLAUDE-winui-alternative.md: WinUI 3 alternative.
Start: "Read CLAUDE.md and do milestone 1."

## Build and run

Requirements: Flutter (stable), Visual Studio 2022 with the "Desktop development with C++" workload, and
**Rust** (`rustup`, needed by `smtc_windows` for media keys and the Windows media overlay).

```
flutter pub get
flutter run -d windows
flutter test
```

Sign in with your Navidrome address and a username and password (or an API key). Everything else is in
`docs/dev-notes.md` (how to verify work, animation and performance rules) and `milestones.md` (status and plan).
