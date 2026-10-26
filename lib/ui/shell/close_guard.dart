import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/providers/session_persistence.dart';

/// Holds the window open for a moment when it is closed (the title bar's X,
/// Alt+F4, the taskbar), so the queue and position can reach the server first:
/// they are sent when you pause, but a window closed mid-song would otherwise
/// lose up to 30 seconds of position. `main` turns on `setPreventClose`.
/// It waits two seconds at most, then closes whatever happened.
class CloseGuard extends StatefulWidget {
  const CloseGuard({super.key, required this.child});

  final Widget child;

  @override
  State<CloseGuard> createState() => _CloseGuardState();
}

class _CloseGuardState extends State<CloseGuard> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    try {
      await flushSessionPersistence().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Closing matters more than saving.
    }
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
