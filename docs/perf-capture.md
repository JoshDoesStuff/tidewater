# Capturing performance data (for the next round of fixes)

Everything below works in a **profile** build only. It takes about 10 minutes. The more of it you do, the less
guessing the next round needs.

## 1. Start the app with the detailed tracing on

```
flutter run -d windows --profile --trace-skia --endless-trace-buffer
```

* `--trace-skia` adds the graphics thread's own steps (each draw, image upload, shader compile) to the DevTools
  timeline. `--endless-trace-buffer` keeps the whole run instead of the last few seconds.
* The console prints `PERF LOG: C:\Users\...\Temp\tidewater_perf.log`. That file gets one line per slow frame
  (over 10 ms on either thread) with what the app was doing (cards built and pictured, covers read from disk,
  downloaded, decoded and shown, live versus pictured cards, the raster cache, scroll speed). Claude can read it
  straight from disk, so you do not need to paste it.

Keys while the app runs:

| Keys | Does |
|---|---|
| Ctrl+Alt+M | writes `MARK 1`, `MARK 2`... into the log, to split it into the steps below |
| Ctrl+Alt+T | names every widget build, layout and paint in the DevTools timeline (only while recording a trace; it costs time itself) |
| Ctrl+Alt+1 to 9, 0 | the switches in `lib/app/perf_flags.dart` (each press is written to the log) |

## 2. The run (press Ctrl+Alt+M before each step)

Do it on the **monitor** at fullscreen first; the laptop afterwards if there is time.

1. Library, Albums tab. Wait 5 s. Then fling down fast through rows you have not seen for about 10 s. Stop and wait 3 s.
2. Scroll back up the same way (these covers are now in memory and on disk).
3. Artists. Same as step 1.
4. Library, Songs tab. Fling down fast for 10 s.
5. Home. Leave it alone for 10 s (idle cost while music plays), then move the mouse over the cards for 5 s.
6. Open Now Playing with lyrics on, leave it 10 s, then let it go idle (no mouse) for 10 s.
7. Quit the app (close the window), so the log is complete.

Then tell Claude "the log is ready". The file is at the path printed at start
(normally `C:\Users\Josh\AppData\Local\Temp\tidewater_perf.log`).

## 3. A DevTools trace of one bad moment (the most useful single thing)

1. In the `flutter run` console, find the line
   `The Flutter DevTools debugger and profiler on Windows is available at: http://127.0.0.1:...`
   and open it in a browser. Go to the **Performance** tab.
2. In the app, press **Ctrl+Alt+T** (detailed timeline on).
3. In DevTools, clear the frames (the trash icon) so the trace stays small.
4. Do step 1 of the run above (a fast fling through unseen rows) for about 5 s.
5. In DevTools, click one of the red (slow) frames to check something was recorded, then use **Export** (the
   download icon at the top right of the Performance page). It saves a `dart_devtools_*.json` file to Downloads.
6. Press Ctrl+Alt+T again in the app (detailed timeline off).
7. Tell Claude the file name. Claude reads it from `C:\Users\Josh\Downloads\`.

If the file is huge (hundreds of MB), do a shorter fling (2 to 3 s).

## What the next round looks for

* In the log: whether slow frames line up with covers being decoded or shown, cards being pictured, cards being
  built, or nothing in particular (then it is the drawing itself); and the raster cache numbers (if the picture
  cache bytes jump around, the engine is caching and throwing away).
* In the trace: on the raster thread, image uploads (`TextureUpload`, `SkImage`), shader compiles (`GrGLProgram`,
  `compile`), `saveLayer`; on the UI thread, which widgets build or lay out in the long frames.
