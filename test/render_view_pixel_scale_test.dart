// Copyright (c) 2026 GraphX by roipeker.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';
import 'package:graphx/graphx_extension.dart';

void main() {
  test(
    'legacy Stage rendering keeps target and effective pixel scale equal',
    () {
      final probe = _PixelScaleProbe();
      final root = GRoot()..addChild(probe);
      final stage = GStage(root)
        ..mount()
        ..setViewport(100, 100, devicePixelRatio: 2);
      final recorder = PictureRecorder();
      final renderer = GCanvasRenderer();

      renderer.render(Canvas(recorder), stage);

      expect(probe.targetPixelScale, 2);
      expect(probe.viewScale, 1);
      expect(probe.pixelScale, 2);

      renderer.dispose();
      recorder.endRecording().dispose();
      stage.dispose();
    },
  );

  test('explicit render-view scale multiplies effective world pixel scale', () {
    final probe = _PixelScaleProbe();
    final root = GRoot()..addChild(probe);
    final stage = GStage(root)
      ..mount()
      ..setViewport(100, 100, devicePixelRatio: 2);
    final viewTransform = GMatrix2()..setValues(2, 0, 0, 3, 0, 0);
    stage.renderViews.add(
      GRenderView(viewport: GRect(0, 0, 100, 100), transform: viewTransform),
    );
    final recorder = PictureRecorder();
    final renderer = GCanvasRenderer();

    renderer.render(Canvas(recorder), stage);

    expect(probe.targetPixelScale, 2);
    expect(probe.viewScale, 3);
    expect(probe.pixelScale, 6);

    renderer.dispose();
    recorder.endRecording().dispose();
    stage.dispose();
  });

  test(
    'offscreen render sessions own target scale independently of Stage',
    () async {
      final probe = _PixelScaleProbe();
      final root = GRoot()..addChild(probe);
      final render = GRenderSession(width: 32, height: 32, scale: 4);

      final texture = await render.render(root);

      expect(probe.targetPixelScale, 4);
      expect(probe.viewScale, 1);
      expect(probe.pixelScale, 4);

      texture.dispose();
      render.dispose();
      root.dispose();
    },
  );
}

final class _PixelScaleProbe extends GNode {
  _PixelScaleProbe() {
    setPaintSelf(true);
  }

  double targetPixelScale = double.nan;
  double viewScale = double.nan;
  double pixelScale = double.nan;

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, 8, 8);

  @override
  void paintSelf(GRenderContext context) {
    targetPixelScale = context.targetPixelScale;
    viewScale = context.viewScale;
    pixelScale = context.pixelScale;
    context.canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xffffffff),
    );
  }
}
