import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('color transforms concatenate parent after local', () {
    const parent = GColorTransform(
      redMultiplier: .5,
      greenMultiplier: .75,
      alphaMultiplier: .8,
      redOffset: 10,
      greenOffset: 20,
      alphaOffset: 5,
    );
    const local = GColorTransform(
      redMultiplier: .25,
      greenMultiplier: .5,
      alphaMultiplier: .5,
      redOffset: 40,
      greenOffset: 8,
      alphaOffset: 10,
    );

    final result = GColorTransform.combine(parent, local);
    expect(result.redMultiplier, .125);
    expect(result.greenMultiplier, .375);
    expect(result.alphaMultiplier, .4);
    expect(result.redOffset, 30);
    expect(result.greenOffset, 26);
    expect(result.alphaOffset, 13);
  });

  test('node tint is multiplicative sugar over lazy color transform state', () {
    final node = GNode();
    expect(node.colorTransform, GColorTransform.identity);
    expect(node.tint, isNull);

    node.tint = const Color(0xffff0000);
    expect(node.tint, const Color(0xffff0000));
    expect(node.colorize, isNull);
    expect(
      node.colorTransform,
      const GColorTransform(
        redMultiplier: 1,
        greenMultiplier: 0,
        blueMultiplier: 0,
      ),
    );

    node.tint = null;
    expect(node.colorTransform, GColorTransform.identity);
    expect(node.tint, isNull);
  });

  test('node colorize replaces RGB and multiplies source alpha', () {
    final node = GNode();

    node.colorize = const Color(0x88ff2040);

    expect(node.colorize, const Color(0x88ff2040));
    expect(node.tint, isNull);
    expect(
      node.colorTransform,
      GColorTransform(
        redMultiplier: 0,
        greenMultiplier: 0,
        blueMultiplier: 0,
        alphaMultiplier: const Color(0x88ff2040).a,
        redOffset: 255,
        greenOffset: 32,
        blueOffset: 64,
      ),
    );

    node.colorize = null;
    expect(node.colorTransform, GColorTransform.identity);
    expect(node.colorize, isNull);
  });

  test('colorize getter only resolves exact colorize transforms', () {
    final node = GNode()
      ..colorTransform = const GColorTransform(
        redMultiplier: 0,
        greenMultiplier: 0,
        blueMultiplier: 0,
        alphaMultiplier: .5,
        redOffset: 12,
        greenOffset: 34,
        blueOffset: 56,
      );

    expect(node.colorize, const Color.fromARGB(128, 12, 34, 56));

    node.colorTransform = const GColorTransform(
      redMultiplier: .25,
      greenMultiplier: 0,
      blueMultiplier: 0,
      redOffset: 12,
      greenOffset: 34,
      blueOffset: 56,
    );
    expect(node.colorize, isNull);
  });

  test('renderer carries concatenated color state to descendants', () {
    final root = GRoot()
      ..colorTransform = const GColorTransform(
        redMultiplier: .5,
        redOffset: 10,
      );
    final group = root.addChild(
      GNode()
        ..colorTransform = const GColorTransform(
          redMultiplier: .5,
          redOffset: 20,
        ),
    );
    final leaf = group.addChild(_ColorCaptureNode());
    final stage = GStage(root)..mount();
    stage.setViewport(64, 64);

    _render(stage);

    expect(
      leaf.colorAtPaint,
      const GColorTransform(redMultiplier: .25, redOffset: 20),
    );
    stage.dispose();
  });

  test('Graphics applies color transform without a fallback layer', () {
    final root = GRoot();
    final shape = root.addChild(
      GShape()
        ..tint = const Color(0xffff0000)
        ..compositeMode = GCompositeMode.direct,
    );
    shape.graphics
      ..beginFill(const Color(0xffffffff))
      ..drawRect(0, 0, 24, 24);

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(64, 64);

    _render(stage);
    expect(stage.stats.render.saveLayers.value, 0);

    stage.dispose();
  });

  test('colorize keeps Graphics on the direct color-transform path', () {
    final root = GRoot();
    final shape = root.addChild(
      GShape()
        ..colorize = const Color(0x88ff0000)
        ..compositeMode = GCompositeMode.direct,
    );
    shape.graphics
      ..beginFill(const Color(0xffffffff))
      ..drawRect(0, 0, 24, 24);

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(64, 64);

    _render(stage);
    expect(stage.stats.render.saveLayers.value, 0);

    stage.dispose();
  });

  test('text uses one bounded fallback layer for color transform', () {
    final root = GRoot();
    root.addChild(GText('GraphX')..tint = const Color(0xffff0000));
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(200, 60);

    _render(stage);
    expect(stage.stats.render.saveLayers.value, 1);

    stage.dispose();
  });
}

void _render(GStage stage) {
  final recorder = PictureRecorder();
  final renderer = GCanvasRenderer();
  renderer.render(Canvas(recorder), stage);
  renderer.dispose();
  recorder.endRecording().dispose();
}

final class _ColorCaptureNode extends GNode {
  _ColorCaptureNode() {
    setPaintSelf(true);
  }

  GColorTransform? colorAtPaint;

  @override
  void paintSelf(GRenderContext context) {
    colorAtPaint = context.colorTransform;
  }
}
