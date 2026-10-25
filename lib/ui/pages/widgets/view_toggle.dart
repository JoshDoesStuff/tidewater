import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';
import '../../widgets/pressable.dart';

/// List / cards switch: the selected side squares off and takes the fill.
class ViewToggle extends StatelessWidget {
  const ViewToggle({super.key, required this.cards, required this.onChanged});

  final bool cards;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _side(context, Icons.view_list_rounded, 'Show as list', !cards, () => onChanged(false)),
        const SizedBox(width: 4),
        _side(context, Icons.grid_view_rounded, 'Show as cards', cards, () => onChanged(true)),
      ],
    );
  }

  Widget _side(BuildContext context, IconData icon, String label, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, s) => Tooltip(
        message: label,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: 52,
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? scheme.secondaryContainer
                : (s.hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(selected || s.pressed ? 16 : 24),
          ),
          child: Icon(icon, size: 22, color: selected ? scheme.onSecondaryContainer : scheme.onSurface),
        ),
      ),
    );
  }
}
