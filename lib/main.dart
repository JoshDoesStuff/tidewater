import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/playback/real_engine.dart';
import 'app/playback/smtc_controls.dart';
import 'app/providers/system_media_providers.dart';
import 'app/providers/session_providers.dart';
import 'app/providers/settings_providers.dart';
import 'app/session/prefs_session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Media keys and the Windows media overlay; the app runs without them if this fails.
  final smtc = await SmtcControls.create();
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(720, 520),
    center: true,
    title: 'Tidewater',
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    // "Hidden" keeps Windows' own caption buttons drawn over the top right, which
    // cover ours. Frameless removes them; our title bar draws min / max / close and
    // DragToResizeArea (app.dart) supplies the resize edges.
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });
  final prefs = await SharedPreferences.getInstance();
  final store = PrefsSessionStore(prefs);
  // The saved server is trusted without a ping: starting offline must still
  // open the app (its lists show an offline state instead).
  final saved = await store.load();
  runApp(ProviderScope(
    // Failed requests surface as error states with a retry button, not as
    // silent automatic retries.
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      sessionStoreProvider.overrideWithValue(store),
      initialSessionProvider.overrideWithValue(saved),
      realEngineOverride(),
      if (smtc != null) systemMediaProvider.overrideWithValue(smtc),
    ],
    child: const TidewaterApp(),
  ));
}
