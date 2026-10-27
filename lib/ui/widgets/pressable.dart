import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
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
    this.actions,
    this.selected,
    this.single = false,
  });

  final Widget Function(BuildContext context, PressState state) builder;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final MouseCursor? cursor;

  /// Other things a screen reader can do with this control (the buttons inside it: like,
  /// more...), by name; see [single].
  final Map<String, VoidCallback>? actions;

  /// Whether it is picked (announced as selected).
  final bool? selected;

  /// Makes the control one accessibility node, with [semanticLabel] and [actions] standing
  /// in for what is inside it. For a row that holds its own buttons (like, more) that
  /// would otherwise be a dozen nodes each; not for a control with real buttons in it
  /// that screen readers should reach (the mini player).
  final bool single;

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
      selected: widget.selected,
      excludeSemantics: widget.single && widget.semanticLabel != null,
      customSemanticsActions: {
        for (final e in (widget.actions ?? const <String, VoidCallback>{}).entries) CustomSemanticsAction(label: e.key): e.value,
      },
      onTap: widget.onTap,
      // Hover comes from a MouseRegion, not FocusableActionDetector, whose
      // hover callback depends on the focus highlight mode.
      child: MouseRegion(
        cursor: widget.cursor ?? (enabled ? SystemMouseCursors.click : MouseCursor.defer),
        onEnter: (_) => _set(hovered: true),
        onExit: (_) => _set(hovered: false),
        child: FocusableActionDetector(
          enabled: enabled,
          onShowFocusHighlight: (v) => _set(focused: v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              widget.onTap?.call();
              return null;
            }),
          },
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            // Space is the global play/pause key; it must not also press a focused
            // button (Flutter would otherwise map it to ActivateIntent).
            SingleActivator(LogicalKeyboardKey.space): DoNothingIntent(),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _set(pressed: true),
            onTapUp: (_) => _set(pressed: false),
            onTapCancel: () => _set(pressed: false),
            onTap: widget.onTap,
            // A ring around the control while it has keyboard focus (not mouse focus).
            child: CustomPaint(
              foregroundPainter: _focused ? _FocusRing(Theme.of(context).colorScheme.primary) : null,
              child: widget.builder(context, (hovered: _hovered, pressed: _pressed, focused: _focused)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded outline just outside the control: pill-shaped for wide controls,
/// circular for square ones.
class _FocusRing extends CustomPainter {
  _FocusRing(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final rect = Offset.zero & size;
    final radius = math.min(size.shortestSide / 2, 28.0) + gap;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(gap), Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRing old) => old.color != color;
}
