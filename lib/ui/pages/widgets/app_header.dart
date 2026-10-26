import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/playback_providers.dart';
import '../../../app/providers/session_providers.dart';
import '../../../app/providers/ui_providers.dart';
import '../../../app/theme/motion.dart';
import '../../../core/api/server_config.dart';
import '../../widgets/animated_glyphs.dart';
import '../../widgets/expressive_buttons.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shapes/morph_path.dart';
import '../../widgets/shapes/morph_shape.dart';

/// Search pill, cast button and avatar along the top of a page.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: SearchPill()),
        SizedBox(width: 12),
        ExpressiveIconButton(
          icon: Icons.cast_rounded,
          tooltip: 'Cast',
          glyph: castGlyph,
        ),
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
                  AnimatedGlyph(kind: GlyphKind.search, size: 24, color: scheme.onSurfaceVariant, hovered: _hovered || _focus.hasFocus),
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

class _Avatar extends ConsumerWidget {
  const _Avatar();

  Future<void> _openMenu(BuildContext context, WidgetRef ref, ServerConfig? server) async {
    final scheme = Theme.of(context).colorScheme;
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height + 6), ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, 0),
      Offset.zero & overlay.size,
    );
    final text = Theme.of(context).textTheme;
    final choice = await showMenu<String>(
      context: context,
      position: position,
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                server?.username.isNotEmpty == true ? server!.username : 'Signed in',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              if (server != null)
                Text(server.baseUrl.host, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: scheme.onSurface),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Sign out or switch server',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (choice == 'signout') {
      ref.read(nowPlayingOpenProvider.notifier).set(false);
      await ref.read(playbackProvider.notifier).stop();
      await ref.read(sessionProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final server = ref.watch(sessionProvider);
    final name = server?.username ?? '';
    final initial = name.isEmpty ? null : name.characters.first.toUpperCase();
    return Pressable(
      onTap: () => _openMenu(context, ref, server),
      semanticLabel: name.isEmpty ? 'Account' : 'Account: $name',
      // A circle at rest that springs into the scalloped "cookie" on hover
      // and spins slowly, like the album tiles.
      builder: (context, s) => SizedBox.square(
        dimension: 48,
        child: MorphShape(
          params: const ShapeParams(lobes: 9, amp: .12, base: .9),
          exponent: 2,
          morph: s.hovered ? 1 : 0,
          spin: s.hovered && !Motion.reduced(context) ? .9 : 0,
          shadow: false,
          child: ColoredBox(
            color: scheme.tertiaryContainer,
            child: Center(
              child: initial == null
                  ? Icon(Icons.person_rounded, size: 24, color: scheme.onTertiaryContainer)
                  : _Initial(letter: initial, color: scheme.onTertiaryContainer),
            ),
          ),
        ),
      ),
    );
  }
}

/// A capital letter centered by its ink, not its line box: text boxes carry
/// uneven space above and below the letters, so a plain Text looks off-center
/// in a circle. The baseline is placed so half the cap height sits above the
/// middle and half below.
class _Initial extends StatelessWidget {
  const _Initial({required this.letter, required this.color});

  final String letter;
  final Color color;

  static const _fontSize = 20.0;
  static const _capHeight = .71 * _fontSize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
          color: color,
        );
    return CustomPaint(
      size: const Size.square(48),
      painter: _InitialPainter(letter, style ?? TextStyle(color: color)),
    );
  }
}

class _InitialPainter extends CustomPainter {
  _InitialPainter(this.letter, this.style);

  final String letter;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: letter, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, size.height / 2 + _Initial._capHeight / 2 - baseline),
    );
  }

  @override
  bool shouldRepaint(_InitialPainter old) => old.letter != letter || old.style != style;
}
