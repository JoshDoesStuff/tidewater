import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/selection.dart';
import '../../core/models/track.dart';

/// Wrap the songs a page shows (a sliver or a box) so Ctrl+A can pick them all,
/// and, with [remove], so the selection bar can take them out of the list.
class SelectionScope extends ConsumerStatefulWidget {
  const SelectionScope({super.key, required this.tracks, required this.child, this.remove, this.removeLabel = 'Remove'});

  final List<Track> tracks;
  final Future<void> Function(List<Track> picked)? remove;
  final String removeLabel;
  final Widget child;

  @override
  ConsumerState<SelectionScope> createState() => _SelectionScopeState();
}

class _SelectionScopeState extends ConsumerState<SelectionScope> {
  late final SelectionScopeNotifier _scope = ref.read(selectionScopeProvider.notifier);

  void _register() {
    Future.microtask(() {
      if (!mounted) return;
      _scope.set(this, SelectionScopeData(tracks: widget.tracks, remove: widget.remove, removeLabel: widget.removeLabel));
    });
  }

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(SelectionScope old) {
    super.didUpdateWidget(old);
    _register();
  }

  @override
  void dispose() {
    // After this frame: the next page may be setting its own already.
    final scope = _scope;
    final me = this;
    Future.microtask(() => scope.release(me));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
