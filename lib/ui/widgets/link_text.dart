import 'package:flutter/material.dart';

import '../../app/perf_flags.dart';

import '../../app/theme/app_theme.dart';

/// One line of text that underlines on hover and opens something when tapped
/// (an album title, an artist name). Plain text when [onTap] is null.
class LinkText extends StatefulWidget {
  const LinkText({super.key, required this.text, required this.style, this.onTap, this.alignment = AlignmentDirectional.centerStart});

  final String text;
  final TextStyle? style;
  final VoidCallback? onTap;

  /// Where the words sit in the room they are given (start, or centered in a column).
  final AlignmentGeometry alignment;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: PerfFlags.instance, builder: (context, _) => PerfFlags.instance.text ? _link(context) : const SizedBox(height: 16));
  }

  Widget _link(BuildContext context) {
    final style = widget.style?.copyWith(decoration: _hovered && widget.onTap != null ? TextDecoration.underline : null);
    final label = Text(widget.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.script(widget.text, style));
    if (widget.onTap == null) return Align(alignment: widget.alignment, widthFactor: 1, heightFactor: 1, child: label);
    // Only the words themselves are the link, not the empty space after them in a wide cell.
    return Align(
      alignment: widget.alignment,
      widthFactor: 1,
      heightFactor: 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: label),
      ),
    );
  }
}
