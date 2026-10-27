import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:flutter/widgets.dart';

/// A [SliverLayoutBuilder] that only builds again when the width changes (or its owner
/// rebuilds), not on every scroll.
///
/// `SliverLayoutBuilder` runs its builder whenever any constraint changes, and the scroll
/// offset is one of them: so a grid made inside it was rebuilt, with every card on screen,
/// on every frame of every scroll. This hands back the very same widget while the width is
/// the same, which Flutter then does not touch at all.
class SliverWidthBuilder extends StatefulWidget {
  const SliverWidthBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, SliverConstraints constraints) builder;

  @override
  State<SliverWidthBuilder> createState() => _SliverWidthBuilderState();
}

class _SliverWidthBuilderState extends State<SliverWidthBuilder> {
  double? _width;
  Widget? _built;

  @override
  void didUpdateWidget(SliverWidthBuilder old) {
    super.didUpdateWidget(old);
    // The owner rebuilt (new data, say): build again at the next layout.
    _built = null;
  }

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (_built == null || _width != constraints.crossAxisExtent) {
          _width = constraints.crossAxisExtent;
          _built = widget.builder(context, constraints);
        }
        return _built!;
      },
    );
  }
}
