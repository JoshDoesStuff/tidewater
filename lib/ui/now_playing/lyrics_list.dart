import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playback_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/lyrics/lyrics.dart';

/// Sizing/dimming recipe for [LyricsList]. [card] is the small list in the
/// lyrics card; [idle] is the big one shown beside the cover in idle mode.
class LyricsStyle {
  const LyricsStyle({
    required this.fontSize,
    required this.activeScale,
    required this.nearScale,
    required this.farScale,
    required this.spacing,
    required this.nearOpacity,
    required this.midOpacity,
    required this.nearBlur,
    required this.midBlur,
    required this.farBlur,
    required this.fade,
  });

  final double fontSize;
  final double activeScale;
  final double nearScale;
  final double farScale;
  final double spacing;
  final double nearOpacity; // distance 1
  final double midOpacity; // distance 2
  final double nearBlur;
  final double midBlur;
  final double farBlur;

  /// Fraction of the height faded at each edge.
  final double fade;

  static const card = LyricsStyle(
    fontSize: 22,
    activeScale: 1.3,
    nearScale: 1,
    farScale: .92,
    spacing: 12,
    nearOpacity: .45,
    midOpacity: .25,
    nearBlur: .8,
    midBlur: 1.5,
    farBlur: 2,
    fade: .25,
  );

  static const idle = LyricsStyle(
    fontSize: 36,
    activeScale: 1.28,
    nearScale: .95,
    farScale: .86,
    spacing: 26,
    nearOpacity: .5,
    midOpacity: .28,
    nearBlur: 1,
    midBlur: 2,
    farBlur: 3,
    fade: .22,
  );
}

/// A single scrolling list of every lyric line. The active line is large,
/// accent colored and kept vertically centered by translating the whole list;
/// other lines dim and blur with distance. Lines are never removed, they
/// animate. Unsynced lyrics are a plain scrollable list with no highlight.
class LyricsList extends ConsumerStatefulWidget {
  const LyricsList({super.key, required this.style, this.layoutWidth});

  final LyricsStyle style;

  /// Width lines wrap at (before scaling). Defaults to available width over
  /// the active scale so the enlarged line still fits.
  final double? layoutWidth;

  @override
  ConsumerState<LyricsList> createState() => _LyricsListState();
}

class _LyricsListState extends ConsumerState<LyricsList> {
  final _columnKey = GlobalKey();
  List<GlobalKey> _keys = const [];
  int _active = 0;
  double _offset = 0;
  bool _measured = false;
  double _height = 0;
  ValueNotifier<Duration>? _position;

  @override
  void initState() {
    super.initState();
    final position = ref.read(positionProvider);
    position.addListener(_onPosition);
    _position = position;
    final lyrics = ref.read(lyricsProvider);
    if (lyrics.synced) _active = lyrics.activeIndexAt(position.value);
  }

  @override
  void dispose() {
    _position?.removeListener(_onPosition);
    super.dispose();
  }

  void _onPosition() {
    final lyrics = ref.read(lyricsProvider);
    if (!lyrics.synced) return;
    final i = lyrics.activeIndexAt(_position!.value);
    if (i != _active) {
      setState(() => _active = i);
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted || _active >= _keys.length) return;
    final columnBox = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    final lineBox = _keys[_active].currentContext?.findRenderObject() as RenderBox?;
    if (columnBox == null || lineBox == null || !columnBox.attached || !lineBox.attached) return;
    final top = lineBox.localToGlobal(Offset.zero, ancestor: columnBox).dy;
    final target = _height / 2 - (top + lineBox.size.height / 2);
    if (target != _offset || !_measured) {
      setState(() {
        _offset = target;
        _measured = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider);
    final scheme = Theme.of(context).colorScheme;
    final st = widget.style;
    if (lyrics.isEmpty) return const SizedBox.shrink();
    if (_keys.length != lyrics.lines.length) {
      _keys = List.generate(lyrics.lines.length, (_) => GlobalKey());
      _scheduleMeasure();
    }
    if (!lyrics.synced) return _PlainList(lyrics: lyrics, style: st);

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxHeight != _height) {
          _height = box.maxHeight;
          _scheduleMeasure();
        }
        final width = widget.layoutWidth ?? box.maxWidth / st.activeScale;
        final animate = _measured && !Motion.reduced(context);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.onSurface.withValues(alpha: 0),
              scheme.onSurface,
              scheme.onSurface,
              scheme.onSurface.withValues(alpha: 0),
            ],
            stops: [0, st.fade, 1 - st.fade, 1],
          ).createShader(r),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              minWidth: 0,
              maxWidth: width,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _offset),
                duration: animate ? const Duration(milliseconds: 900) : Duration.zero,
                curve: Motion.emphasized,
                builder: (context, y, child) => Transform.translate(offset: Offset(0, y), child: child),
                child: Column(
                  key: _columnKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, line) in lyrics.lines.indexed)
                      _Line(
                        key: _keys[i],
                        line: line,
                        distance: (i - _active).abs(),
                        style: st,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.line, required this.distance, required this.style});

  final LyricLine line;
  final int distance;
  final LyricsStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = distance;
    final opacity = d == 0 ? 1.0 : d == 1 ? style.nearOpacity : d == 2 ? style.midOpacity : .2;
    final blur = d == 0 ? 0.0 : d == 1 ? style.nearBlur : d == 2 ? style.midBlur : style.farBlur;
    final scale = d == 0 ? style.activeScale : d == 1 ? style.nearScale : style.farScale;
    final reduced = Motion.reduced(context);
    final slow = reduced ? Duration.zero : const Duration(milliseconds: 800);
    final scaleDur = reduced ? Duration.zero : const Duration(milliseconds: 900);
    return Padding(
      padding: EdgeInsets.only(bottom: style.spacing),
      child: AnimatedOpacity(
        opacity: opacity,
        duration: slow,
        curve: Motion.emphasized,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: blur),
          duration: slow,
          curve: Motion.emphasized,
          builder: (context, sigma, child) => sigma < .05
              ? child!
              : ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
                  child: child,
                ),
          child: AnimatedScale(
            scale: scale,
            alignment: Alignment.centerLeft,
            duration: scaleDur,
            curve: Motion.emphasized,
            child: AnimatedDefaultTextStyle(
              duration: reduced ? Duration.zero : const Duration(milliseconds: 600),
              curve: Motion.standard,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: style.fontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                    color: d == 0 ? scheme.primary : scheme.onSurface,
                  ),
              child: Text(line.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlainList extends StatelessWidget {
  const _PlainList({required this.lyrics, required this.style});

  final Lyrics lyrics;
  final LyricsStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        for (final l in lyrics.lines)
          Padding(
            padding: EdgeInsets.only(bottom: style.spacing),
            child: Text(
              l.text,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: style.fontSize,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
            ),
          ),
      ],
    );
  }
}
