import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/ui_providers.dart';
import '../../app/theme/motion.dart';

/// Short messages (a play request that failed, the server going away) in a
/// pill above the mini player. Each message stays for 4 s.
class ToastLayer extends ConsumerStatefulWidget {
  const ToastLayer({super.key});

  @override
  ConsumerState<ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends ConsumerState<ToastLayer> {
  Toast? _shown;
  bool _visible = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _onToast(Toast? toast) {
    if (toast == null) return;
    _hide?.cancel();
    final wasShowing = _visible;
    setState(() {
      _shown = toast;
      // A new toast starts out of sight and then comes in, so there is something to animate.
      _visible = wasShowing;
    });
    if (!wasShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
    _hide = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _visible = false);
      ref.read(toastProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(toastProvider, (_, next) => _onToast(next));
    final toast = _shown;
    if (toast == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // In the album's colors, like the rest of the app: not a fixed light or dark pill.
    final bg = toast.error ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = toast.error
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    final accent = toast.error ? scheme.error : scheme.primary;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 112),
        child: IgnorePointer(
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, .8),
            // Comes in with a spring, leaves a little faster.
            duration: Motion.of(
              context,
              _visible ? Motion.slow : Motion.medium,
            ),
            curve: Motion.curve(
              context,
              _visible ? Motion.spring : Motion.standard,
            ),
            child: AnimatedScale(
              scale: _visible ? 1 : .9,
              duration: Motion.of(
                context,
                _visible ? Motion.slow : Motion.medium,
              ),
              curve: Motion.curve(
                context,
                _visible ? Motion.spring : Motion.standard,
              ),
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: Motion.of(context, Motion.medium),
                child: Semantics(
                  liveRegion: true,
                  label: toast.message,
                  child: ExcludeSemantics(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      padding: const EdgeInsets.fromLTRB(16, 12, 22, 12),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: accent.withValues(alpha: .35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: .3),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            toast.error
                                ? Icons.error_rounded
                                : Icons.check_circle_rounded,
                            size: 20,
                            color: accent,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              toast.message,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: fg,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
