import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test(
    'direct rendering carries effective alpha without public world state',
    () {
      final root = GRoot()..alpha = .8;
      final parent = root.addChild(GNode()..alpha = .5);
      final child = parent.addChild(_AlphaNode()..alpha = .25);
      final stage = GStage(root)..mount();
      stage.setViewport(100, 100);

      _render(stage);
      expect(child.paintAlpha, closeTo(.1, 1e-12));

      root.alpha = .4;
      _render(stage);
      expect(child.paintAlpha, closeTo(.05, 1e-12));

      final other = root.addChild(GNode()..alpha = .25);
      other.addChild(child);
      _render(stage);
      expect(child.paintAlpha, closeTo(.025, 1e-12));

      stage.dispose();
    },
  );

  test('layer isolates local alpha but preserves inherited direct alpha', () {
    final root = GRoot()..alpha = .8;
    final group = root.addChild(
      GNode()
        ..alpha = .5
        ..compositeMode = GCompositeMode.layer,
    );
    final child = group.addChild(_AlphaNode()..alpha = .25);
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(child.paintAlpha, closeTo(.2, 1e-12));
    expect(stage.stats.render.saveLayers.value, 1);

    stage.dispose();
  });

  test('rect clip stays direct', () {
    final root = GRoot();
    final group = root.addChild(GNode()..clip = GClip.rect(0, 0, 20, 20));
    group.addChild(_BoxNode());
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    final render = stage.stats.render;
    expect(render.clipsApplied.value, 1);
    expect(render.saveLayers.value, 0);

    stage.dispose();
  });

  test('path clip stays direct', () {
    final path = Path()..addOval(const Rect.fromLTWH(0, 0, 20, 20));
    final root = GRoot();
    final group = root.addChild(GNode()..clip = GClip.path(path));
    group.addChild(_BoxNode());
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    final render = stage.stats.render;
    expect(render.clipsApplied.value, 1);
    expect(render.saveLayers.value, 0);

    stage.dispose();
  });

  test('inverse path clip resolves from owner bounds and stays direct', () {
    final hole = Path()..addOval(const Rect.fromLTWH(4, 4, 8, 8));
    final root = GRoot();
    final group = root.addChild(GNode()..clip = GClip.inversePath(hole));
    group.addChild(_BoxNode());
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    _render(stage);
    final render = stage.stats.render;
    expect(render.clipsApplied.value, 2);
    expect(render.saveLayers.value, 0);

    stage.dispose();
  });

  test('mask auto-isolates and mask source is not drawn normally', () {
    final root = GRoot();
    final target = root.addChild(GNode());
    final content = target.addChild(_BoxNode());
    final mask = root.addChild(_BoxNode());
    target.mask = mask;

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    final render = stage.stats.render;
    expect(content.paintCount, 1);
    expect(mask.paintCount, 1);
    expect(render.masksApplied.value, 1);
    expect(render.saveLayers.value, 2);

    stage.dispose();
  });

  test('inverse mask uses the same isolated compositor path', () {
    final root = GRoot();
    final target = root.addChild(GNode());
    target.addChild(_BoxNode());
    final mask = root.addChild(_BoxNode());
    target
      ..mask = mask
      ..maskMode = GMaskMode.alphaInverse;

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    final render = stage.stats.render;
    expect(target.maskMode, GMaskMode.alphaInverse);
    expect(render.masksApplied.value, 1);
    expect(render.saveLayers.value, 2);

    stage.dispose();
  });

  test('non-default node blend auto-isolates', () {
    final root = GRoot();
    root.addChild(_BoxNode()..blendMode = BlendMode.plus);
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(stage.stats.render.saveLayers.value, 1);

    stage.dispose();
  });

  test('composite state defaults cleanly and can return to defaults', () {
    final node = GNode();
    expect(node.compositeMode, GCompositeMode.auto);
    expect(node.blendMode, BlendMode.srcOver);
    expect(node.clip, isNull);
    expect(node.mask, isNull);
    expect(node.maskMode, GMaskMode.alpha);

    node
      ..compositeMode = GCompositeMode.layer
      ..blendMode = BlendMode.plus
      ..clip = GClip.rect(0, 0, 10, 10)
      ..maskMode = GMaskMode.alphaInverse;
    expect(node.compositeMode, GCompositeMode.layer);
    expect(node.blendMode, BlendMode.plus);
    expect(node.clip, isNotNull);
    expect(node.maskMode, GMaskMode.alphaInverse);

    node
      ..clip = null
      ..maskMode = GMaskMode.alpha
      ..compositeMode = GCompositeMode.auto
      ..blendMode = BlendMode.srcOver;
    expect(node.compositeMode, GCompositeMode.auto);
    expect(node.blendMode, BlendMode.srcOver);
    expect(node.clip, isNull);
    expect(node.maskMode, GMaskMode.alpha);
  });
}

void _render(GStage stage) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final renderer = GCanvasRenderer();
  renderer.render(canvas, stage);
  renderer.dispose();
  recorder.endRecording().dispose();
}

final class _AlphaNode extends GNode {
  _AlphaNode() {
    setPaintSelf(true);
  }

  double paintAlpha = -1;

  @override
  void paintSelf(GRenderContext context) {
    paintAlpha = context.alpha;
  }
}

final class _BoxNode extends GNode {
  _BoxNode() {
    setPaintSelf(true);
  }

  int paintCount = 0;
  final Paint _paint = Paint()..color = const Color(0xffffffff);

  @override
  void computeSelfBounds(GBounds out) {
    out.setXYWH(0, 0, 24, 24);
  }

  @override
  void paintSelf(GRenderContext context) {
    paintCount++;
    context.canvas.drawRect(const Rect.fromLTWH(0, 0, 24, 24), _paint);
  }
}
