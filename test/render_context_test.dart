import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('fallback opacity layers are counted by render stats', () {
    final stage = GStage(GRoot())..mount();
    stage.stats.enabled = true;
    stage.setViewport(32, 32);

    final recorder = PictureRecorder();
    final context = GRenderContext();
    context.begin(Canvas(recorder), stage);

    context.saveOpacityLayer(const Rect.fromLTWH(0, 0, 16, 16), .5);
    context.canvas.drawRect(
      const Rect.fromLTWH(0, 0, 16, 16),
      Paint()..color = const Color(0xffffffff),
    );
    context.restoreLayer();
    context.end();

    expect(stage.stats.render.saveLayers.value, 1);
    expect(stage.stats.render.canvasSaves.value, 0);

    context.dispose();
    recorder.endRecording().dispose();
    stage.dispose();
  });

  test('ordinary color fallback does not add a hard clip save', () {
    final root = GRoot()
      ..colorTransform = const GColorTransform(blueOffset: 96);
    root.addChild(_FallbackBox());

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(32, 32);
    final recorder = PictureRecorder();
    final renderer = GCanvasRenderer();
    renderer.render(Canvas(recorder), stage);

    expect(stage.stats.render.saveLayers.value, 1);
    expect(stage.stats.render.canvasSaves.value, 0);

    renderer.dispose();
    recorder.endRecording().dispose();
    stage.dispose();
  });

  test('positive AO web fallback cannot escape declared bounds', () async {
    final root = GRoot();
    final background = root.addChild(GShape());
    background.graphics
      ..beginFill(const Color(0xff17351f))
      ..drawRect(0, 0, 32, 32)
      ..endFill();

    final transformed = root.addChild(GNode())
      ..x = 8
      ..y = 8
      ..colorTransform = const GColorTransform(blueOffset: 96, alphaOffset: 96);
    transformed.addChild(_FallbackBox());

    final stage = GStage(root)..mount();
    stage.setViewport(32, 32);
    final recorder = PictureRecorder();
    final renderer = GCanvasRenderer();
    renderer.render(Canvas(recorder), stage);
    renderer.dispose();

    final picture = recorder.endRecording();
    final image = await picture.toImage(32, 32);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);

    final data = bytes!;
    int channel(int x, int y, int channel) =>
        data.getUint8((y * 32 + x) * 4 + channel);

    expect(channel(1, 1, 0), 0x17);
    expect(channel(1, 1, 1), 0x35);
    expect(channel(1, 1, 2), 0x1f);
    expect(channel(1, 1, 3), 0xff);

    image.dispose();
    picture.dispose();
    stage.dispose();
  }, skip: !kIsWeb);
}

final class _FallbackBox extends GNode {
  _FallbackBox() {
    setPaintSelf(true);
  }

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, 8, 8);

  @override
  void paintSelf(GRenderContext context) {
    final clipped = context.saveRenderStateLayer(
      const Rect.fromLTWH(0, 0, 8, 8),
    );
    context.canvas.drawRect(
      const Rect.fromLTWH(2, 2, 4, 4),
      Paint()..color = const Color(0xffffffff),
    );
    context.restoreRenderStateLayer(clipped);
  }
}
