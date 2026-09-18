import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('filters stay lazy and do not change canonical bounds', () {
    final node = _BoxNode();
    final before = node.localBounds;
    expect(node.filters, isEmpty);

    node.filters = [GBlurFilter(blurX: 8, blurY: 4)];
    final after = node.localBounds;
    expect(after.x1, before.x1);
    expect(after.y1, before.y1);
    expect(after.x2, before.x2);
    expect(after.y2, before.y2);

    node.filters = [];
    expect(node.filters, isEmpty);
  });

  test('effect bounds compose child filter, transform, then parent filter', () {
    final outer = GNode();
    outer.addChild(_BoxNode())
      ..x = 20
      ..scaleX = 2
      ..scaleY = 1.5
      ..filters = [GBlurFilter(blurX: 2, blurY: 1)];
    outer.filters = [
      GDropShadowFilter(
        offsetX: 10,
        offsetY: 5,
        blurX: 2,
        blurY: 2,
        color: const Color(0xff000000),
      ),
    ];

    final local = outer.localBounds;
    expect(local.x1, 40);
    expect(local.y1, 15);
    expect(local.x2, 88);
    expect(local.y2, 51);

    final effect = outer.getEffectBounds();
    expect(effect.x1, 28);
    expect(effect.y1, 9.5);
    expect(effect.x2, 116);
    expect(effect.y2, 66.5);
  });

  test('color matrix preserves effect extent', () {
    final node = _BoxNode()..filters = [_matrix()];
    final local = node.localBounds;
    final effect = node.getEffectBounds();
    expect(effect.x1, local.x1);
    expect(effect.y1, local.y1);
    expect(effect.x2, local.x2);
    expect(effect.y2, local.y2);
  });

  test('glow effect bounds include spread and blur', () {
    final node = _BoxNode()
      ..filters = [GGlowFilter(blurX: 2, blurY: 1, spread: 3)];
    final effect = node.getEffectBounds();
    expect(effect.x1, 1);
    expect(effect.y1, 4);
    expect(effect.x2, 43);
    expect(effect.y2, 40);
  });

  test('soft outline effect bounds include width and softness', () {
    final node = _BoxNode()..filters = [GOutlineFilter(width: 3, softness: 1)];
    final effect = node.getEffectBounds();
    expect(effect.x1, 4);
    expect(effect.y1, 4);
    expect(effect.x2, 40);
    expect(effect.y2, 40);
  });

  test('inner shadow and glow preserve source effect bounds', () {
    final node = _BoxNode();
    final local = node.localBounds;

    node.filters = [
      GDropShadowFilter(
        offsetX: 8,
        offsetY: 6,
        blurX: 5,
        blurY: 4,
        inner: true,
      ),
    ];
    var effect = node.getEffectBounds();
    expect(effect.x1, local.x1);
    expect(effect.y1, local.y1);
    expect(effect.x2, local.x2);
    expect(effect.y2, local.y2);

    node.filters = [GGlowFilter(blurX: 6, blurY: 5, spread: 3, inner: true)];
    effect = node.getEffectBounds();
    expect(effect.x1, local.x1);
    expect(effect.y1, local.y1);
    expect(effect.x2, local.x2);
    expect(effect.y2, local.y2);
  });

  test('bevel preserves source effect bounds', () {
    final node = _BoxNode()
      ..filters = [GBevelFilter(offsetX: 7, offsetY: 5, blurX: 4, blurY: 3)];
    final local = node.localBounds;
    final effect = node.getEffectBounds();
    expect(effect.x1, local.x1);
    expect(effect.y1, local.y1);
    expect(effect.x2, local.x2);
    expect(effect.y2, local.y2);
  });

  test('toggling shadow inner updates effect extent in place', () {
    final shadow = GDropShadowFilter(
      offsetX: 8,
      offsetY: 6,
      blurX: 4,
      blurY: 4,
    );
    final node = _BoxNode()..filters = [shadow];
    final outer = node.getEffectBounds();
    expect(outer.x1, lessThan(node.localBounds.x1));
    expect(outer.x2, greaterThan(node.localBounds.x2));

    shadow.inner = true;
    final inner = node.getEffectBounds();
    final local = node.localBounds;
    expect(inner.x1, local.x1);
    expect(inner.y1, local.y1);
    expect(inner.x2, local.x2);
    expect(inner.y2, local.y2);
  });

  test(
    'effect bounds follow rendered active state without changing local bounds',
    () {
      final root = GNode();
      final child = root.addChild(
        _BoxNode()..filters = [GBlurFilter(blurX: 4, blurY: 4)],
      );
      final local = root.localBounds;
      expect(local.isEmpty, isFalse);

      child.active = false;
      expect(root.getEffectBounds().isEmpty, isTrue);
      expect(root.localBounds.isEmpty, isFalse);
    },
  );

  test('blur and color matrix fuse into the existing auto layer', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode());
    node.filters = [GBlurFilter(blurX: 3, blurY: 5), _matrix()];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 1);
    expect(stage.stats.render.saveLayers.value, 1);

    stage.dispose();
  });

  test('drop shadow branches only when explicitly requested', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode());
    node.filters = [_shadow()];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 2);
    expect(stage.stats.render.saveLayers.value, 2);

    stage.dispose();
  });

  test('glow uses the same single outer branch as drop shadow', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode())
      ..filters = [GGlowFilter(blurX: 4, blurY: 4, spread: 2)];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 2);
    expect(stage.stats.render.saveLayers.value, 2);

    stage.dispose();
  });

  test('soft outline keeps one morphology branch', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode())
      ..filters = [GOutlineFilter(width: 3, softness: 1)];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 2);
    expect(stage.stats.render.saveLayers.value, 2);

    stage.dispose();
  });

  test('inner shadow uses three source passes and three layers', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode())
      ..filters = [
        GDropShadowFilter(
          offsetX: 4,
          offsetY: 5,
          blurX: 3,
          blurY: 3,
          inner: true,
        ),
      ];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 3);
    expect(stage.stats.render.saveLayers.value, 3);

    stage.dispose();
  });

  test('inner glow uses three source passes and three layers', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode())
      ..filters = [GGlowFilter(blurX: 4, blurY: 4, spread: 2, inner: true)];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 3);
    expect(stage.stats.render.saveLayers.value, 3);

    stage.dispose();
  });

  test('bevel uses five source passes and five layers', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode())
      ..filters = [GBevelFilter(offsetX: 4, offsetY: 4, blurX: 3, blurY: 3)];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 5);
    expect(stage.stats.render.saveLayers.value, 5);

    stage.dispose();
  });

  test('inner shadow is clipped to source alpha', () async {
    final root = GRoot();
    root.addChild(_BoxNode())
      ..filters = [
        GDropShadowFilter(
          offsetX: 4,
          offsetY: 0,
          blurX: 0,
          blurY: 0,
          color: const Color(0xffff0000),
          inner: true,
        ),
      ];
    final stage = GStage(root)..mount();
    stage.setViewport(48, 48);

    final image = await _renderImage(stage, 48, 48);
    final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;

    expect(_pixel(data, 48, 11, 20), const [255, 0, 0, 255]);
    expect(_pixel(data, 48, 20, 20), const [255, 255, 255, 255]);
    expect(_pixel(data, 48, 7, 20), const [0, 0, 0, 0]);

    image.dispose();
    stage.dispose();
  });

  test('inner glow forms an inside edge without leaking outside', () async {
    final root = GRoot();
    root.addChild(_BoxNode())
      ..filters = [
        GGlowFilter(
          blurX: 0,
          blurY: 0,
          spread: 4,
          color: const Color(0xff00ff00),
          inner: true,
        ),
      ];
    final stage = GStage(root)..mount();
    stage.setViewport(48, 48);

    final image = await _renderImage(stage, 48, 48);
    final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;

    expect(_pixel(data, 48, 11, 20), const [0, 255, 0, 255]);
    expect(_pixel(data, 48, 20, 20), const [255, 255, 255, 255]);
    expect(_pixel(data, 48, 7, 20), const [0, 0, 0, 0]);

    image.dispose();
    stage.dispose();
  });

  test('bevel paints opposite inner highlight and shadow edges', () async {
    final root = GRoot();
    root.addChild(_BoxNode())
      ..filters = [
        GBevelFilter(
          offsetX: 4,
          offsetY: 0,
          blurX: 0,
          blurY: 0,
          highlightColor: const Color(0xffff0000),
          shadowColor: const Color(0xff0000ff),
        ),
      ];
    final stage = GStage(root)..mount();
    stage.setViewport(48, 48);

    final image = await _renderImage(stage, 48, 48);
    final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;

    expect(_pixel(data, 48, 11, 20), const [255, 0, 0, 255]);
    expect(_pixel(data, 48, 20, 20), const [255, 255, 255, 255]);
    expect(_pixel(data, 48, 32, 20), const [0, 0, 255, 255]);
    expect(_pixel(data, 48, 7, 20), const [0, 0, 0, 0]);

    image.dispose();
    stage.dispose();
  });

  test('linear prefix is fused around a trailing shadow', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode());
    node.filters = [GBlurFilter(blurX: 3, blurY: 3), _matrix(), _shadow()];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 2);
    // Outer isolation + shadow branch + one fused prefix per replay.
    expect(stage.stats.render.saveLayers.value, 4);

    stage.dispose();
  });

  test('linear suffix after shadow stays one native pass', () {
    final root = GRoot();
    final node = root.addChild(_BoxNode());
    node.filters = [_shadow(), GBlurFilter(blurX: 3, blurY: 3), _matrix()];
    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(100, 100);

    _render(stage);
    expect(node.paintCount, 2);
    // Outer isolation + fused suffix + shadow branch.
    expect(stage.stats.render.saveLayers.value, 3);

    stage.dispose();
  });

  test('nested child filters are replayed only by the parent shadow branch', () {
    final root = GRoot();
    final outer = root.addChild(GNode())..filters = [_shadow(), _matrix()];
    final children = <_BoxNode>[];
    for (var i = 0; i < 3; ++i) {
      children.add(
        outer.addChild(
          _BoxNode()
            ..x = i * 28
            ..filters = [GBlurFilter(blurX: 2, blurY: 2)],
        ),
      );
    }

    final stage = GStage(root)..mount();
    stage.stats.enabled = true;
    stage.setViewport(160, 100);
    _render(stage);

    for (final child in children) {
      expect(child.paintCount, 2);
    }
    // Outer isolation + matrix suffix + shadow branch = 3.
    // Three child blur layers are replayed by the two shadow source branches = 6.
    expect(stage.stats.render.saveLayers.value, 9);
    stage.dispose();
  });

  test(
    'mutable filter stays attached and requests a fresh filtered render',
    () {
      final root = GRoot();
      final blur = GBlurFilter(blurX: 2, blurY: 2);
      final node = root.addChild(_BoxNode()..filters = [blur]);
      final stage = GStage(root)..mount();
      stage.stats.enabled = true;
      stage.setViewport(100, 100);

      _render(stage);
      blur.setBlur(10, 6);
      _render(stage);
      expect(node.paintCount, 2);
      expect(stage.stats.render.saveLayers.value, 2);

      stage.dispose();
    },
  );

  test('one mutable filter instance cannot be shared across live nodes', () {
    final filter = GBlurFilter();
    final a = GNode()..filters = [filter];
    final b = GNode();

    expect(() => b.filters = [filter], throwsStateError);
    a.filters = [];
    expect(() => b.filters = [filter], returnsNormally);
  });

  test('filter can move after its owner is disposed', () {
    final filter = GBlurFilter();
    final a = GNode()..filters = [filter];
    final b = GNode();

    a.dispose();
    expect(() => b.filters = [filter], returnsNormally);
  });

  test('direct mode rejects filters in debug mode', () {
    final root = GRoot();
    root.addChild(
      _BoxNode()
        ..compositeMode = GCompositeMode.direct
        ..filters = [GBlurFilter()],
    );
    final stage = GStage(root)..mount();
    stage.setViewport(100, 100);

    expect(() => _render(stage), throwsA(isA<AssertionError>()));
    stage.dispose();
  });
}

GColorMatrixFilter _matrix() => GColorMatrixFilter(const <double>[
  .8,
  0,
  0,
  0,
  12,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1.2,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

GDropShadowFilter _shadow() => GDropShadowFilter(
  offsetX: 5,
  offsetY: 7,
  blurX: 4,
  blurY: 4,
  color: const Color(0x99000000),
);

void _render(GStage stage) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final renderer = GCanvasRenderer();
  renderer.render(canvas, stage);
  renderer.dispose();
  recorder.endRecording().dispose();
}

Future<Image> _renderImage(GStage stage, int width, int height) async {
  final recorder = PictureRecorder();
  final renderer = GCanvasRenderer();
  renderer.render(Canvas(recorder), stage);
  renderer.dispose();
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

List<int> _pixel(ByteData data, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return [
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
    data.getUint8(offset + 3),
  ];
}

final class _BoxNode extends GNode {
  _BoxNode() {
    setPaintSelf(true);
  }

  int paintCount = 0;
  final Paint _paint = Paint()..color = const Color(0xffffffff);

  @override
  void computeSelfBounds(GBounds out) {
    out.setXYWH(10, 10, 24, 24);
  }

  @override
  void paintSelf(GRenderContext context) {
    paintCount++;
    context.canvas.drawRect(const Rect.fromLTWH(10, 10, 24, 24), _paint);
  }
}
