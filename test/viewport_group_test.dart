import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';
import 'package:graphx/graphx_extension.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('viewport group skips offscreen direct child before traversal', () {
    final root = GRoot();
    final group = root.addChild(GViewportGroup());
    final visible = group.addChild(_CountingNode())..setPosition(10, 10);
    final offscreen = group.addChild(_CountingNode())..setPosition(140, 10);

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    final recorder = PictureRecorder();
    final renderer = GCanvasRenderer();
    renderer.render(Canvas(recorder), stage);

    expect(visible.paints, 1);
    expect(offscreen.paints, 0);
    expect(stage.stats.render.cullChecks.value, 2);
    expect(stage.stats.render.culledChildren.value, 1);
    expect(stage.stats.render.nodesVisited.value, 3);

    renderer.dispose();
    recorder.endRecording().dispose();
    stage.dispose();
  });

  test('disabled culling preserves ordinary child traversal', () {
    final root = GRoot();
    final group = root.addChild(GViewportGroup())..cullingEnabled = false;
    final offscreen = group.addChild(_CountingNode())..setPosition(140, 10);

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    final recorder = PictureRecorder();
    final renderer = GCanvasRenderer();
    renderer.render(Canvas(recorder), stage);

    expect(offscreen.paints, 1);
    expect(stage.stats.render.cullChecks.value, 0);
    expect(stage.stats.render.culledChildren.value, 0);

    renderer.dispose();
    recorder.endRecording().dispose();
    stage.dispose();
  });

  test('child filter influence is kept visible across viewport edge', () {
    final root = GRoot();
    final group = root.addChild(GViewportGroup());
    final child = group.addChild(_CountingNode(size: 4))
      ..setPosition(103, 20)
      ..filters = [
        GGlowFilter(blurX: 4, blurY: 4, color: const Color(0xffffffff)),
      ];

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    final recorder = PictureRecorder();
    final renderer = GCanvasRenderer();
    renderer.render(Canvas(recorder), stage);

    expect(child.paints, greaterThan(0));
    expect(stage.stats.render.cullChecks.value, 1);
    expect(stage.stats.render.culledChildren.value, 0);

    renderer.dispose();
    recorder.endRecording().dispose();
    stage.dispose();
  });

  test(
    'nested declared GRect rejects subtree without deriving child bounds',
    () {
      final root = GRoot();
      final world = root.addChild(GViewportGroup());
      final sector = world.addChild(
        GViewportGroup(cullBounds: GRect(0, 0, 100, 100), name: 'sector'),
      )..setPosition(500, 0);
      final child = sector.addChild(_BoundsCountingNode());

      final stage = GStage(root)..mount();
      stage.stats.enabled = true;
      stage.setViewport(100, 100);

      final recorder = PictureRecorder();
      final renderer = GCanvasRenderer();
      renderer.render(Canvas(recorder), stage);

      expect(child.boundsCalls, 0);
      expect(child.paints, 0);
      expect(stage.stats.render.culledChildren.value, 1);

      renderer.dispose();
      recorder.endRecording().dispose();
      stage.dispose();
    },
  );

  test(
    'node snapshot bypasses viewport culling and captures full subtree',
    () async {
      final root = GRoot();
      final group = root.addChild(GViewportGroup());
      final child = group.addChild(_CountingNode())..setPosition(150, 10);

      final stage = GStage(root)..mount();
      stage.setViewport(100, 100);

      final texture = await group.snapshot(
        area: GRect(145, 5, 30, 30),
        scale: 1,
      );

      expect(child.paints, 1);

      texture.dispose();
      stage.dispose();
    },
  );
}

class _CountingNode extends GNode {
  _CountingNode({this.size = 10}) {
    setPaintSelf(true);
  }

  static final Paint _paint = Paint()..color = const Color(0xffffffff);

  final double size;
  int paints = 0;

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, size, size);

  @override
  void paintSelf(GRenderContext context) {
    paints++;
    context.canvas.drawRect(Rect.fromLTWH(0, 0, size, size), _paint);
  }
}

final class _BoundsCountingNode extends _CountingNode {
  int boundsCalls = 0;

  @override
  void computeSelfBounds(GBounds out) {
    boundsCalls++;
    super.computeSelfBounds(out);
  }
}
