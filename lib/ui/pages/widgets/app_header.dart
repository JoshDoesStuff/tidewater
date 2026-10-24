import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';
import '../../widgets/expressive_buttons.dart';
import '../../widgets/pressable.dart';

/// Search pill, cast button and avatar along the top of a page.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: SearchPill()),
        SizedBox(width: 12),
        ExpressiveIconButton(icon: Icons.cast_rounded, tooltip: 'Cast'),
        SizedBox(width: 12),
        _Avatar(),
      ],
    );
  }
}

/// 56 px search field that widens from 640 to 720 px on focus.
class SearchPill extends StatefulWidget {
  const SearchPill({super.key});

  @override
  State<SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<SearchPill> {
  final _focus = FocusNode();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final target = _focus.hasFocus ? 720.0 : 640.0;
        return Align(
          alignment: Alignment.centerLeft,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.slow),
              curve: Motion.curve(context, Motion.spring),
              width: target.clamp(0.0, box.maxWidth),
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: _hovered || _focus.hasFocus ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      focusNode: _focus,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search your library',
                        hintStyle: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () {},
      semanticLabel: 'Account',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.curve(context, Motion.spring),
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(s.hovered ? 14 : 24),
        ),
        child: Text(
          'J',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onTertiaryContainer,
              ),
        ),
      ),
    );
  }
}
