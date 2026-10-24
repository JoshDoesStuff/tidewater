import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef PressState = ({bool hovered, bool pressed, bool focused});

/// Hover / press / focus tracking with keyboard activation, for the custom
/// expressive controls that morph their shape on state.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    this.onTap,
    this.semanticLabel,
    this.cursor,
  });

  final Widget Function(BuildContext context, PressState state) builder;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final MouseCursor? cursor;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _set({bool? hovered, bool? pressed, bool? focused}) {
    setState(() {
      _hovered = hovered ?? _hovered;
      _pressed = pressed ?? _pressed;
      _focused = focused ?? _focused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: widget.cursor ?? (enabled ? SystemMouseCursors.click : MouseCursor.defer),
        onShowHoverHighlight: (v) => _set(hovered: v),
        onShowFocusHighlight: (v) => _set(focused: v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(pressed: true),
          onTapUp: (_) => _set(pressed: false),
          onTapCancel: () => _set(pressed: false),
          onTap: widget.onTap,
          child: widget.builder(context, (hovered: _hovered, pressed: _pressed, focused: _focused)),
        ),
      ),
    );
  }
}
