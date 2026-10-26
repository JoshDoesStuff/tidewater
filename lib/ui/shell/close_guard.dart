import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/providers/session_persistence.dart';
import '../../app/theme/motion.dart';
import '../widgets/squiggle_loader.dart';

/// Holds the window open for a moment when it is closed (the title bar's X,
/// Alt+F4, the taskbar), so the queue and position can reach the server first:
/// they are sent when you pause, but a window closed mid-song would otherwise
/// lose up to 30 seconds of position. `main` turns on `setPreventClose`.
///
/// It waits two seconds at most, then closes whatever happened. If saving takes
/// longer than a blink, a "Wrapping up" screen covers the window so a slow
/// server does not look like a frozen app.
class CloseGuard extends StatefulWidget {
  const CloseGuard({super.key, required this.child, this.save, this.onClosed});

  final Widget child;

  /// What to send before closing (the queue and position); the real one by default.
  final Future<void> Function()? save;

  /// What closes the window; the real one by default. (Tests replace both.)
  final Future<void> Function()? onClosed;

  /// How long a save may take before the "wrapping up" screen appears.
  static const showAfter = Duration(milliseconds: 250);

  /// The longest the window waits for the server.
  static const giveUpAfter = Duration(seconds: 2);

  @override
  State<CloseGuard> createState() => _CloseGuardState();
}

class _CloseGuardState extends State<CloseGuard> with WindowListener {
  bool _closing = false;
  bool _showWrapUp = false;

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
  void onWindowClose() => close();

  /// Saves, then closes. Called when the window is asked to close.
  Future<void> close() async {
    if (_closing) return; // a second click while waiting changes nothing
    _closing = true;
    final slow = Timer(CloseGuard.showAfter, () {
      if (mounted) setState(() => _showWrapUp = true);
    });
    try {
      await (widget.save ?? flushSessionPersistence)().timeout(CloseGuard.giveUpAfter);
    } catch (_) {
      // Closing matters more than saving.
    }
    slow.cancel();
    await (widget.onClosed ?? windowManager.destroy)();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: widget.child),
        if (_showWrapUp)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reduced ? 1 : 0, end: 1),
              duration: Motion.fast,
              builder: (context, t, child) => Opacity(opacity: t, child: child),
              child: const _WrapUp(),
            ),
          ),
      ],
    );
  }
}

class _WrapUp extends StatelessWidget {
  const _WrapUp();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: scheme.surface.withValues(alpha: .94),
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: 'Wrapping up. Saving your place on the server.',
          child: ExcludeSemantics(
            child: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SquiggleLoader(active: true),
                  const SizedBox(height: 18),
                  DefaultTextStyle(
                    style: (text.titleLarge ?? const TextStyle()).copyWith(color: scheme.onSurface),
                    child: const Text('Wrapping up…'),
                  ),
                  const SizedBox(height: 6),
                  DefaultTextStyle(
                    style: (text.bodyMedium ?? const TextStyle()).copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                    child: const Text('Saving your queue and place to the server'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
