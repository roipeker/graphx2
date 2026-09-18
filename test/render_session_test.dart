import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'render session renders detached trees into a fixed logical surface',
    () async {
      final root = GNode('detached')
        ..x = 500
        ..y = 300;
      root.addChild(GShape()).graphics
        ..beginFill(const ui.Color(0xffff3366))
        ..drawRect(10, 8, 20, 16)
        ..endFill();

      final session = GRenderSession(width: 64, height: 48, scale: 2);
      final texture = await session.render(root);
      final pixels = await _pixels(texture.image);

      expect(root.isAttached, isFalse);
      expect(texture.width, 64);
      expect(texture.height, 48);
      expect(texture.image.width, 128);
      expect(texture.image.height, 96);
      expect(_alphaAt(pixels, 128, 4, 4), 0);
      expect(_alphaAt(pixels, 128, 24, 20), greaterThan(0));

      texture.dispose();
      session.dispose();
      root.dispose();
    },
  );

  test('render context hosted pixel scale follows the Stage viewport', () {
    final stage = GStage(GRoot())
      ..mount()
      ..setViewport(32, 24, devicePixelRatio: 2.5);
    final recorder = ui.PictureRecorder();
    final context = GRenderContext();
    context.begin(ui.Canvas(recorder), stage);
    expect(context.pixelScale, 2.5);
    context.end();
    recorder.endRecording().dispose();
    context.dispose();
    stage.dispose();
  });

  test('render session scale owns offscreen pixel scale', () async {
    final node = _PixelScaleNode();
    final session = GRenderSession(width: 16, height: 16, scale: 4);
    final texture = await session.render(node);
    expect(node.lastPixelScale, 4);

    texture.dispose();
    session.dispose();
    node.dispose();
  });

  test(
    'renderStage uses session output scale instead of Stage viewport DPR',
    () async {
      final root = _PixelScaleRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(16, 16, devicePixelRatio: 2);
      final session = GRenderSession(width: 16, height: 16, scale: 3);
      final texture = await session.renderStage(stage);

      expect(root.node.lastPixelScale, 3);
      expect(stage.devicePixelRatio, 2);

      texture.dispose();
      session.dispose();
      stage.dispose();
    },
  );

  test('render session reuses renderer state across captures', () async {
    final shape = GShape();
    shape.graphics
      ..beginFill(const ui.Color(0xffff0000))
      ..drawRect(0, 0, 16, 16)
      ..endFill();

    final session = GRenderSession(width: 16, height: 16);
    final first = await session.render(shape);
    final firstPixels = await _pixels(first.image);

    shape.graphics
      ..clear()
      ..beginFill(const ui.Color(0xff0066ff))
      ..drawRect(0, 0, 16, 16)
      ..endFill();
    final second = await session.render(shape);
    final secondPixels = await _pixels(second.image);

    expect(
      _rgbaAt(firstPixels, 16, 8, 8),
      isNot(_rgbaAt(secondPixels, 16, 8, 8)),
    );

    first.dispose();
    second.dispose();
    session.dispose();
    shape.dispose();
  });

  test(
    'stage can drive an unhosted simulation rendered by a session',
    () async {
      final root = _SimulationRoot();
      final stage = GStage(root, 1.0, false)
        ..mount()
        ..setViewport(64, 48, devicePixelRatio: 2);

      expect(stage.isHosted, isFalse);
      expect(root.isAttached, isTrue);
      expect(root.attachCount, 1);

      stage.tick(.5);
      expect(stage.elapsed, closeTo(.5, 1e-9));
      expect(root.shape.x, closeTo(5, 1e-9));

      final session = GRenderSession(width: stage.width, height: stage.height);
      final texture = await session.renderStage(stage);
      final pixels = await _pixels(texture.image);

      expect(_alphaAt(pixels, 64, 6, 2), greaterThan(0));
      expect(stage.isHosted, isFalse);
      expect(root.attachCount, 1);

      texture.dispose();
      session.dispose();
      stage.dispose();
    },
  );

  test(
    'detached render rejects structural mutation and releases its lock',
    () async {
      final node = _RenderAddingNode();
      final session = GRenderSession(width: 16, height: 16);

      await expectLater(session.render(node), throwsStateError);
      expect(node.numChildren, 0);
      expect(node.isDisposed, isFalse);

      node.mutate = false;
      node.addChild(GNode());
      expect(node.numChildren, 1);

      final texture = await session.render(node);
      texture.dispose();
      session.dispose();
      node.dispose();
    },
  );

  test(
    'detached render lock prevents moving a rendered node to another tree',
    () async {
      final destination = GNode('destination');
      final root = GNode('source');
      final node = root.addChild(_RenderReparentingNode(destination));
      final session = GRenderSession(width: 16, height: 16);

      await expectLater(session.render(root), throwsStateError);

      expect(node.parent, same(root));
      expect(root.numChildren, 1);
      expect(destination.numChildren, 0);

      node.reparentOnPaint = false;
      destination.addChild(node);
      expect(node.parent, same(destination));

      session.dispose();
      root.dispose();
      destination.dispose();
    },
  );

  test(
    'same render session rejects recursive recording and recovers',
    () async {
      final node = _RecursiveRenderNode();
      final session = GRenderSession(width: 16, height: 16);
      node.session = session;

      await expectLater(session.render(node), throwsStateError);
      expect(session.isDisposed, isFalse);

      node.recurse = false;
      final texture = await session.render(node);
      texture.dispose();

      session.dispose();
      node.dispose();
    },
  );

  test('renderStage requires Stage root lifecycle attachment', () async {
    final stage = GStage(GRoot())..mount();
    final session = GRenderSession(width: 16, height: 16);

    await expectLater(session.renderStage(stage), throwsStateError);

    stage.setViewport(16, 16);
    final texture = await session.renderStage(stage);
    texture.dispose();

    session.dispose();
    stage.dispose();
  });

  test('disposed render session rejects further rendering', () {
    final node = GNode();
    final session = GRenderSession(width: 10, height: 10)..dispose();
    expect(() => session.render(node), throwsStateError);
    node.dispose();
  });
}

final class _SimulationRoot extends GRoot {
  late final GShape shape;
  int attachCount = 0;

  @override
  void attached() {
    attachCount++;
    shape = addChild(GShape());
    shape.graphics
      ..beginFill(const ui.Color(0xffffffff))
      ..drawRect(0, 0, 4, 4)
      ..endFill();
    updatesEnabled = true;
  }

  @override
  void update(double delta) {
    shape.x += delta * 10;
  }
}

final class _PixelScaleRoot extends GRoot {
  late final _PixelScaleNode node;

  @override
  void attached() {
    node = addChild(_PixelScaleNode());
  }
}

final class _PixelScaleNode extends GNode {
  _PixelScaleNode() {
    setPaintSelf(true);
  }

  double? lastPixelScale;

  @override
  void paintSelf(GRenderContext context) {
    lastPixelScale = context.pixelScale;
  }
}

final class _RenderAddingNode extends GNode {
  _RenderAddingNode() {
    setPaintSelf(true);
  }

  bool mutate = true;

  @override
  void paintSelf(GRenderContext context) {
    if (mutate) addChild(GNode());
  }
}

final class _RenderReparentingNode extends GNode {
  _RenderReparentingNode(this.destination) {
    setPaintSelf(true);
  }

  final GNode destination;
  bool reparentOnPaint = true;

  @override
  void paintSelf(GRenderContext context) {
    if (reparentOnPaint) destination.addChild(this);
  }
}

final class _RecursiveRenderNode extends GNode {
  _RecursiveRenderNode() {
    setPaintSelf(true);
  }

  GRenderSession? session;
  bool recurse = true;

  @override
  void paintSelf(GRenderContext context) {
    if (recurse) unawaited(session!.render(this));
  }
}

Future<Uint8List> _pixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

int _alphaAt(Uint8List pixels, int width, int x, int y) =>
    pixels[(y * width + x) * 4 + 3];

int _rgbaAt(Uint8List pixels, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return pixels[offset] << 24 |
      pixels[offset + 1] << 16 |
      pixels[offset + 2] << 8 |
      pixels[offset + 3];
}
