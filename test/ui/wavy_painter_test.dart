import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/widgets/wavy_progress.dart';

WavyPainter _painter({
  double frac = 0,
  bool buffering = false,
  double sweepAlpha = 0,
  double handle = 1,
  double dotShrink = 0,
}) =>
    WavyPainter(
      repaint: ValueNotifier(0),
      fraction: () => frac,
      amplitude: () => 3,
      phase: () => 0,
      dragging: () => false,
      buffering: () => buffering,
      sweep: () => .5,
      handle: () => handle,
      dotShrink: () => dotShrink,
      sweepAlpha: () => sweepAlpha,
      wavelength: 18,
      strokeWidth: 4,
      padding: 2,
      played: Colors.pink,
      track: Colors.grey,
    );

int _paths(WavyPainter p) {
  final canvas = TestRecordingCanvas();
  p.paint(canvas, const Size(400, 30));
  return canvas.invocations.where((i) => i.invocation.memberName == #drawPath).length;
}

int _circles(WavyPainter p) {
  final canvas = TestRecordingCanvas();
  p.paint(canvas, const Size(400, 30));
  return canvas.invocations.where((i) => i.invocation.memberName == #drawCircle).length;
}

void main() {
  test('the buffering squiggle and the wave are never drawn together', () {
    // Retracting after the wait began: the wave only.
    expect(_paths(_painter(frac: .4, buffering: true, sweepAlpha: 1)), 1);
    // Wave gone, still waiting: the squiggle only.
    expect(_paths(_painter(frac: 0, buffering: true, sweepAlpha: 1)), 1);
    // The wait just ended and the squiggle is fading: still only the squiggle.
    expect(_paths(_painter(frac: 0, sweepAlpha: .5)), 1);
    // Playing normally mid-bar: the wave only.
    expect(_paths(_painter(frac: .4)), 1);
  });

  test('the end dot goes away with the handle that shrinks into it', () {
    expect(_circles(_painter(frac: .5)), 1, reason: 'dot at rest');
    expect(_circles(_painter(frac: 1, dotShrink: 1)), 0, reason: 'gone once the handle has shrunk into it');
  });
}
