import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('stage and node hitTest return top-most visual geometry', () {
    final (:root, :stage) = _scene();
    final back = root.addChild(_HitBox(100, 100));
    final front = root.addChild(_HitBox(50, 50))
      ..x = 20
      ..y = 20;
    expect(stage.hitTest(30, 30), same(front));
    expect(root.hitTest(30, 30), same(front));
    expect(stage.hitTest(90, 90), same(back));
    expect(stage.hitTest(150, 150), isNull);
  });

  test('objectsUnderPointInto is front-to-back and reusable', () {
    final (:root, :stage) = _scene();
    final back = root.addChild(_HitBox(100, 100));
    final front = root.addChild(_HitBox(50, 50))
      ..x = 20
      ..y = 20;
    final out = <GNode>[GNode()];
    stage.objectsUnderPointInto(30, 30, out);
    expect(out, [front, back]);
    stage.objectsUnderPointInto(150, 150, out);
    expect(out, isEmpty);
  });

  test('geometry inspection ignores pointer routing flags', () {
    final (:root, :stage) = _scene();
    final box = root.addChild(_HitBox(80, 60));
    box.pointer.enabled = false;
    box.pointer.children = false;
    expect(stage.hitTest(20, 20), same(box));
    expect(box.hitTest(20, 20), same(box));
  });

  test('node hitTest scopes transformed descendant geometry', () {
    final (:root, :stage) = _scene();
    final parent = root.addChild(GNode())
      ..x = 40
      ..y = 30;
    final child = parent.addChild(_HitBox(30, 20))
      ..x = 10
      ..y = 5;
    expect(parent.hitTest(55, 40), same(child));
    expect(parent.hitTest(45, 32), isNull);
    expect(stage.hitTest(55, 40), same(child));
  });

  test('singular transform cannot produce a hit', () {
    final (:root, :stage) = _scene();
    final back = root.addChild(_HitBox(100, 100));
    root.addChild(_HitBox(80, 80))
      ..scaleX = 0
      ..x = 10;
    expect(stage.hitTest(20, 20), same(back));
  });

  test('stage hit inspection resolves explicit render view coordinates', () {
    final (:root, :stage) = _scene();
    final box = root.addChild(_HitBox(20, 20))
      ..x = 50
      ..y = 40;
    stage.renderViews.add(
      GRenderView(
        viewport: GRect(100, 20, 200, 100),
        transform: GMatrix2(2, 0, 0, 2, -20, -40),
      ),
    );

    expect(stage.hitTest(190, 70), same(box));
    expect(stage.hitTest(55, 45), isNull);
    expect(root.hitTest(55, 45), same(box));

    final out = <GNode>[];
    stage.objectsUnderPointInto(190, 70, out);
    expect(out, [box]);
    stage.dispose();
  });

  test('stage hit inspection respects render-group masks', () {
    final (:root, :stage) = _scene();
    final worldMask = GRenderMask.bit(0);
    final hudMask = GRenderMask.bit(1);
    final world = root.addChild(GRenderGroup(mask: worldMask));
    final hud = root.addChild(GRenderGroup(mask: hudMask));
    final worldBox = world.addChild(_HitBox(40, 40))
      ..x = 20
      ..y = 20;
    hud.addChild(_HitBox(40, 40))
      ..x = 20
      ..y = 20;
    stage.renderViews.add(
      GRenderView(viewport: GRect(0, 0, 300, 200), mask: worldMask),
    );

    expect(stage.hitTest(30, 30), same(worldBox));
    stage.dispose();
  });

  test('stage hit inspection uses top-most input-enabled render view', () {
    final (:root, :stage) = _scene();
    final box = root.addChild(_HitBox(20, 20))
      ..x = 40
      ..y = 40;
    stage.renderViews
      ..add(
        GRenderView(
          viewport: GRect(0, 0, 100, 100),
          transform: GMatrix2(1, 0, 0, 1, -40, -40),
        ),
      )
      ..add(
        GRenderView(
          viewport: GRect(0, 0, 100, 100),
          transform: GMatrix2(1, 0, 0, 1, 30, 30),
          inputEnabled: false,
        ),
      );

    expect(stage.hitTest(5, 5), same(box));
    stage.dispose();
  });

  test('local bounds cache follows child geometry and transforms', () {
    final (:root, :stage) = _scene();
    final parent = root.addChild(GNode());
    final child = parent.addChild(_MutableBox(20, 10))
      ..x = 10
      ..y = 5;
    final out = GBounds.empty();

    expect(identical(parent.getLocalBounds(out), out), isTrue);
    expect((out.x1, out.y1, out.x2, out.y2), (10, 5, 30, 15));

    child.x = 30;
    parent.getLocalBounds(out);
    expect((out.x1, out.y1, out.x2, out.y2), (30, 5, 50, 15));

    child.setSize(40, 12);
    parent.getLocalBounds(out);
    expect((out.x1, out.y1, out.x2, out.y2), (30, 5, 70, 17));

    final copy = parent.getLocalBounds();
    expect(identical(copy, out), isFalse);
    expect((copy.x1, copy.y1, copy.x2, copy.y2), (30, 5, 70, 17));
    stage.dispose();
  });

  test('getBounds reuses output and stays tight across nested rotations', () {
    final (:root, :stage) = _scene();
    final parent = root.addChild(GNode())
      ..x = 100
      ..y = 60;
    final a = parent.addChild(_HitBox(20, 10))
      ..x = 10
      ..rotation = math.pi / 2;
    parent.addChild(_HitBox(10, 10))
      ..x = 60
      ..y = 5;

    final out = GBounds.empty();
    expect(identical(parent.getBounds(root, out), out), isTrue);
    expect(out.x1, closeTo(100, 1e-9));
    expect(out.y1, closeTo(60, 1e-9));
    expect(out.x2, closeTo(170, 1e-9));
    expect(out.y2, closeTo(80, 1e-9));

    final local = parent.getBounds(parent);
    expect(local.x1, closeTo(0, 1e-9));
    expect(local.x2, closeTo(70, 1e-9));
    expect(a.getLocalBounds().width, 20);
    stage.dispose();
  });

  test('localToNodeInto converts through cached world transforms', () {
    final (:root, :stage) = _scene();
    final source = root.addChild(GNode())
      ..x = 100
      ..y = 40;
    final target = root.addChild(GNode())
      ..x = 20
      ..y = 10;
    final out = GPoint();
    expect(source.localToNodeInto(target, 5, 7, out), isTrue);
    expect(out.x, 85);
    expect(out.y, 37);
    final copy = source.localToNode(target, 5, 7)!;
    expect(copy.x, 85);
    expect(copy.y, 37);
    stage.dispose();
    final detached = GNode();
    expect(source.localToNodeInto(detached, 0, 0, out), isFalse);
  });

  test(
    'name is optional metadata and direct child lookup is deterministic',
    () {
      final parent = GNode();
      final first = parent.addChild(GNode(name: 'item'));
      parent.addChild(GNode(name: 'item'));
      expect(parent.name, isNull);
      expect(parent.getChildByName('item'), same(first));
      expect(parent.getChildByName('missing'), isNull);
    },
  );
}

({GRoot root, GStage stage}) _scene() {
  final root = GRoot();
  final stage = GStage(root);
  stage.mount();
  stage.setViewport(300, 200);
  stage.consumePaintRequest();
  return (root: root, stage: stage);
}

class _HitBox extends GNode {
  _HitBox(this.width, this.height);
  double width;
  double height;
  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, width, height);
}

final class _MutableBox extends _HitBox {
  _MutableBox(super.width, super.height);
  void setSize(double width, double height) {
    this.width = width;
    this.height = height;
    invalidateBounds();
  }
}
