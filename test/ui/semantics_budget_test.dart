// ignore_for_file: deprecated_member_use
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/ui/pages/widgets/album_card.dart' show MediaCard;

import '../support/fake_library.dart';
import '../support/pump.dart';

/// Windows reports "AXTree" errors when the accessibility tree is large, churns every
/// frame, or hands nodes a "traversal parent" elsewhere in the tree (what Flutter's
/// `Tooltip` does). These tests keep the app inside a budget so that stays fixed.
SemanticsNode _root(WidgetTester tester) => tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;

({int nodes, int traversal}) _count(WidgetTester tester) {
  var nodes = 0;
  var traversal = 0;
  void walk(SemanticsNode n) {
    nodes++;
    if (n.getSemanticsData().traversalParentIdentifier != null) traversal++;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(_root(tester));
  return (nodes: nodes, traversal: traversal);
}

String _dump(WidgetTester tester) => _root(tester).toStringDeep(childOrder: DebugSemanticsDumpOrder.inverseHitTest);

Future<ProviderContainer> _app(WidgetTester tester, {FakeLibraryApi? api}) async {
  final c = await pumpApp(tester, api: api);
  return c;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('no page hands a node a traversal parent (no Flutter Tooltip anywhere)', (tester) async {
    final c = await _app(tester);
    final handle = tester.ensureSemantics();
    for (final path in ['/', '/library', '/lists', '/radio', '/liked', '/settings', '/album/a1']) {
      c.read(routerProvider).go(path);
      await advance(tester, const Duration(seconds: 2));
      expect(_count(tester).traversal, 0, reason: '$path has a Tooltip');
    }
    handle.dispose();
    await disposeApp(tester);
  });

  testWidgets('a long playlist stays a handful of nodes per row', (tester) async {
    final api = FakeLibraryApi();
    api.playlistSongs['pl-1'] = [for (var i = 0; i < 150; i++) fakeTracks[i % fakeTracks.length]];
    final c = await _app(tester, api: api);
    final handle = tester.ensureSemantics();
    c.read(routerProvider).go('/playlist/pl-1');
    await advance(tester, const Duration(seconds: 2));
    await _settle(tester);
    // About a dozen rows are on screen; each is the reorder wrapper (two nodes) and one for the song.
    expect(_count(tester).nodes, lessThan(180));
    handle.dispose();
    await disposeApp(tester);
  });

  testWidgets('hovering cards, and a window left alone, change nothing in the tree', (tester) async {
    final c = await _app(tester);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(seconds: 2));
    final handle = tester.ensureSemantics();
    await _settle(tester);
    var last = _dump(tester);
    var changed = 0;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    final cards = find.byType(MediaCard);
    final a = tester.getCenter(cards.first);
    final b = tester.getCenter(cards.at(2));
    for (var i = 0; i < 40; i++) {
      await mouse.moveTo(Offset.lerp(a, b, i / 39)! - const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 30));
      if (_dump(tester) != last) changed++;
      last = _dump(tester);
    }
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (_dump(tester) != last) changed++;
      last = _dump(tester);
    }
    expect(changed, 0, reason: 'the tree changed while only hovering or idling');
    handle.dispose();
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('Now Playing with the queue open is a modest tree and has no traversal parents', (tester) async {
    final c = await _app(tester);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
    await advance(tester, const Duration(seconds: 1));
    c.read(nowPlayingOpenProvider.notifier).set(true);
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 3));
    final handle = tester.ensureSemantics();
    await _settle(tester);
    final n = _count(tester);
    expect(n.traversal, 0);
    expect(n.nodes, lessThan(200));
    handle.dispose();
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });
}
