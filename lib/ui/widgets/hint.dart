import 'dart:async';

import 'package:flutter/material.dart';

/// A tooltip that is not Flutter's `Tooltip`.
///
/// `Tooltip` puts every button it wraps under an `OverlayPortal`, which gives its
/// accessibility node a "traversal parent" in another part of the tree. With a few
/// hundred of them on screen (a button on every song row) Windows reports a flood of
/// `AXTree` errors. This one draws the same little label from a plain overlay
/// entry, outside the accessibility tree, and leaves the button's node alone
/// (the message becomes the node's tooltip text).
class Hint extends StatefulWidget {
  const Hint({super.key, required this.message, required this.child, this.delay = const Duration(milliseconds: 500)});

  final String message;
  final Widget child;
  final Duration delay;

  @override
  State<Hint> createState() => _HintState();
}

class _HintState extends State<Hint> {
  Timer? _timer;
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null || !mounted || widget.message.isEmpty) return;
    final box = context.findRenderObject();
    final overlay = Overlay.maybeOf(context);
    if (box is! RenderBox || !box.attached || overlay == null) return;
    final target = box.localToGlobal(Offset.zero) & box.size;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final message = widget.message;
    _entry = OverlayEntry(
      builder: (context) {
        final screen = MediaQuery.sizeOf(context);
        final below = target.bottom + 8 + 34 < screen.height;
        return Positioned(
          left: 0,
          right: 0,
          top: below ? target.bottom + 8 : null,
          bottom: below ? null : screen.height - target.top + 8,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Align(
                alignment: Alignment.topLeft,
                child: Transform.translate(
                  offset: Offset((target.center.dx - 80).clamp(8.0, screen.width - 168), 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: scheme.inverseSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(message, style: text.bodySmall?.copyWith(color: scheme.onInverseSurface)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _timer?.cancel();
        _timer = Timer(widget.delay, _show);
      },
      onExit: (_) => _hide(),
      child: Listener(
        onPointerDown: (_) => _hide(),
        child: Semantics(tooltip: widget.message, child: widget.child),
      ),
    );
  }
}

/// An [IconButton] with a [Hint] (and the same name for screen readers) in place of
/// its built-in tooltip.
class HintIconButton extends StatelessWidget {
  const HintIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.iconSize,
    this.visualDensity,
    this.color,
    this.style,
    this.selectedIcon,
    this.isSelected,
    this.filledTonal = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final double? iconSize;
  final VisualDensity? visualDensity;
  final Color? color;
  final ButtonStyle? style;
  final Widget? selectedIcon;
  final bool? isSelected;
  final bool filledTonal;

  @override
  Widget build(BuildContext context) {
    final button = filledTonal
        ? IconButton.filledTonal(
            onPressed: onPressed,
            icon: icon,
            iconSize: iconSize,
            visualDensity: visualDensity,
            color: color,
            style: style,
            selectedIcon: selectedIcon,
            isSelected: isSelected,
          )
        : IconButton(
            onPressed: onPressed,
            icon: icon,
            iconSize: iconSize,
            visualDensity: visualDensity,
            color: color,
            style: style,
            selectedIcon: selectedIcon,
            isSelected: isSelected,
          );
    return Hint(
      message: tooltip,
      // The name a screen reader says, since the button has no tooltip of its own.
      child: Semantics(label: tooltip, button: true, excludeSemantics: true, onTap: onPressed, enabled: onPressed != null, child: button),
    );
  }
}
