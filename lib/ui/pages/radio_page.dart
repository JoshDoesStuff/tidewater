import '../widgets/sliver_width_builder.dart';
import '../widgets/hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/providers/radio_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/radio_station.dart';
import '../widgets/async_states.dart';
import '../widgets/effects/eq_bars.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/stagger_in.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import 'page_frame.dart';

/// The server's internet radio stations: tap one to listen, add, edit or remove them.
class RadioPage extends ConsumerWidget {
  const RadioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final stations = ref.watch(radioStationsProvider);
    final n = stations.value?.length;
    final subtitle = n == null
        ? (stations.hasError ? 'Couldn\'t load stations' : 'Loading…')
        : '$n station${n == 1 ? '' : 's'}';
    return PageFrame(
      child: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(500),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 36, 40, 22),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LetterReveal(text: 'Radio', style: text.displaySmall, delay: const Duration(milliseconds: 100)),
                        Text(
                          subtitle,
                          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  ExpressivePillButton(
                    label: 'Add station',
                    icon: Icons.add_rounded,
                    onPressed: () => showStationDialog(context, ref),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 40, PageFrame.bottomClearance),
            sliver: _content(ref, stations),
          ),
        ],
      ),
    );
  }

  Widget _content(WidgetRef ref, AsyncValue<List<RadioStation>> stations) {
    if (stations.hasError && !stations.hasValue) {
      return SliverToBoxAdapter(
        child: ErrorPanel(error: stations.error!, onRetry: () => ref.invalidate(radioStationsProvider)),
      );
    }
    if (!stations.hasValue) return const SliverToBoxAdapter(child: SkeletonBox(height: 120, radius: 32));
    final list = stations.requireValue;
    if (list.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyPanel(
          icon: Icons.radio_rounded,
          title: 'No stations yet',
          message: 'Add an internet radio station with its stream address. Your server keeps the list.',
        ),
      );
    }
    return SliverWidthBuilder(
      builder: (context, c) {
        final columns = StaggerIn.columnsFor(c.crossAxisExtent, 340, 14);
        return SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 340,
            mainAxisExtent: 96,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) =>
              StaggerIn(index: StaggerIn.wave(i, columns), child: _StationCard(station: list[i], index: i)),
        );
      },
    );
  }
}

class _StationCard extends ConsumerWidget {
  const _StationCard({required this.station, required this.index});

  final RadioStation station;
  final int index;

  static String _host(String url) => Uri.tryParse(url)?.host ?? url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = ref.watch(currentTrackIdProvider) == 'radio:${station.id}';
    final playing = current && ref.watch(playbackProvider.select((s) => s.playing));
    final player = ref.read(playbackProvider.notifier);
    final (bg, fg) = switch (index % 3) {
      0 => (scheme.primaryContainer, scheme.onPrimaryContainer),
      1 => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    };

    Future<void> menu(Offset at) async {
      final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
      final choice = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(Rect.fromLTWH(at.dx, at.dy, 0, 0), Offset.zero & overlay.size),
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        items: const [
          PopupMenuItem(value: 'edit', child: Text('Edit…')),
          PopupMenuItem(value: 'delete', child: Text('Remove')),
        ],
      );
      if (!context.mounted) return;
      if (choice == 'edit') {
        await showStationDialog(context, ref, station: station);
      } else if (choice == 'delete') {
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: scheme.surfaceContainerHigh,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text('Remove "${station.name}"?'),
            content: const Text('It is removed from the server\'s list, for everyone who uses it.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
            ],
          ),
        );
        if (yes == true) await ref.read(radioActionsProvider).delete(station);
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (d) => menu(d.globalPosition),
      child: Pressable(
        onTap: () => current ? player.toggle() : player.playStation(station),
        single: true,
        actions: {
          'More options': () {
            final box = context.findRenderObject()! as RenderBox;
            menu(box.localToGlobal(box.size.center(Offset.zero)));
          },
        },
        semanticLabel: '${station.name}, ${_host(station.streamUrl)}${current ? ', playing' : ''}',
        builder: (context, s) => AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: bg.withValues(alpha: current || s.hovered ? 1 : .85),
            borderRadius: BorderRadius.circular(s.pressed ? 22 : (current ? 40 : 32)),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fg.withValues(alpha: .14), borderRadius: BorderRadius.circular(18)),
                  child: Center(
                    child: current
                        ? MiniEq(animating: playing, color: fg, size: 20)
                        : Icon(s.hovered ? Icons.play_arrow_rounded : Icons.radio_rounded, color: fg),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _host(station.streamUrl),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: fg.withValues(alpha: .8)),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: s.hovered ? 1 : 0,
                alwaysIncludeSemantics: true,
                duration: Motion.of(context, Motion.fast),
                child: Builder(
                  builder: (menuContext) => HintIconButton(
                    tooltip: 'More',
                    color: fg,
                    onPressed: () {
                      final box = menuContext.findRenderObject()! as RenderBox;
                      menu(box.localToGlobal(Offset(0, box.size.height)));
                    },
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a station's name and stream address (and, if wanted, its website), then
/// adds it, or with [station] saves the changes to it.
Future<void> showStationDialog(BuildContext context, WidgetRef ref, {RadioStation? station}) async {
  final result = await showDialog<({String name, String url, String? home})>(
    context: context,
    builder: (_) => _StationDialog(station: station),
  );
  if (result == null) return;
  final actions = ref.read(radioActionsProvider);
  if (station == null) {
    await actions.add(result.name, result.url, result.home);
  } else {
    await actions.edit(station, result.name, result.url, result.home);
  }
}

class _StationDialog extends StatefulWidget {
  const _StationDialog({this.station});

  final RadioStation? station;

  @override
  State<_StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends State<_StationDialog> {
  late final _name = TextEditingController(text: widget.station?.name);
  late final _url = TextEditingController(text: widget.station?.streamUrl);
  late final _home = TextEditingController(text: widget.station?.homepageUrl);
  String? _urlError;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _home.dispose();
    super.dispose();
  }

  void _save() {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (_name.text.trim().isEmpty) return;
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      setState(() => _urlError = 'Use a full address starting with http:// or https://');
      return;
    }
    final home = _home.text.trim();
    Navigator.of(context).pop((name: _name.text.trim(), url: url, home: home.isEmpty ? null : home));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.station == null ? 'Add station' : 'Edit station'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: InputDecoration(labelText: 'Stream address', errorText: _urlError, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _home,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(labelText: 'Website (optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(widget.station == null ? 'Add' : 'Save')),
      ],
    );
  }
}
