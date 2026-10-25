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
    setState(() {
      _shown = toast;
      _visible = true;
    });
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
    final bg = toast.error ? scheme.errorContainer : scheme.inverseSurface;
    final fg = toast.error ? scheme.onErrorContainer : scheme.onInverseSurface;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 112),
        child: IgnorePointer(
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, .6),
            duration: Motion.of(context, Motion.slow),
            curve: Motion.curve(context, Motion.emphasized),
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: Motion.of(context, Motion.medium),
              child: Semantics(
                liveRegion: true,
                label: toast.message,
                child: ExcludeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .3), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Text(toast.message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg)),
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
