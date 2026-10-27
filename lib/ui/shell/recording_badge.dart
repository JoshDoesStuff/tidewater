import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/frame_log.dart';

/// Profile builds only: while a screen recording is marked (Ctrl+Alt+R), a badge at the top
/// shows the profile log's clock and a frame count, so a frame of the video can be matched to
/// the lines of the log written at that moment. Starting and stopping also flash a thick
/// border for half a second, easy to find when scrubbing through the video.
class RecordingBadge extends StatefulWidget {
  const RecordingBadge({super.key});

  @override
  State<RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<RecordingBadge> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) {
    _frames++;
    _clock.value = perfClockSeconds;
  });
  final _clock = ValueNotifier<double>(0);
  int _frames = 0;
  bool _flash = false;
  int _flashes = 0;

  @override
  void initState() {
    super.initState();
    perfRecording.addListener(_changed);
  }

  void _changed() {
    final on = perfRecording.value;
    if (on) {
      _frames = 0;
      _ticker.start();
    } else {
      _ticker.stop();
    }
    final flash = ++_flashes;
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && flash == _flashes) setState(() => _flash = false);
    });
  }

  @override
  void dispose() {
    perfRecording.removeListener(_changed);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kProfileMode && !kDebugMode) return const SizedBox.shrink();
    final on = perfRecording.value;
    if (!on && !_flash) return const SizedBox.shrink();
    // Fixed colors on purpose: this is a measuring aid, and must look the same in every theme
    // so it is easy to spot in a video.
    const red = Color(0xFFFF1744);
    const green = Color(0xFF00E676);
    return IgnorePointer(
      child: Stack(
        children: [
          if (_flash) Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: on ? red : green, width: 12)))),
          if (on || _flash)
            Positioned(
              top: 44,
              left: 0,
              right: 0,
              child: Center(
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: const Color(0xE6000000), borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: ValueListenableBuilder<double>(
                        valueListenable: _clock,
                        builder: (context, t, _) => Text(
                          on
                              ? '● REC  t=${t.toStringAsFixed(2)}s  frame $_frames'
                              : '■ STOPPED  t=${perfClockSeconds.toStringAsFixed(2)}s  $_frames frames',
                          style: TextStyle(
                            color: on ? red : green,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
