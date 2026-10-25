import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/providers/session_providers.dart';
import 'app/providers/settings_providers.dart';
import 'app/session/prefs_session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(720, 520),
    center: true,
    title: 'Tidewater',
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
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
    ],
    child: const TidewaterApp(),
  ));
}
