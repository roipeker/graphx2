// Copyright (c) 2026 GraphX by roipeker.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'snapshot works detached with local effect bounds and logical scale',
    () async {
      final shape = GShape()
        ..x = 90
        ..y = 70;
      shape.graphics
        ..beginFill(const ui.Color(0xffffffff))
        ..drawRect(0, 0, 20, 10)
        ..endFill();
      shape.filters = [GBlurFilter(blurX: 2, blurY: 1)];

      expect(shape.isAttached, isFalse);
      expect(() => shape.stage, throwsStateError);
      final texture = await shape.snapshot(scale: 2);
      expect(shape.isAttached, isFalse);
      expect(() => shape.stage, throwsStateError);
      expect(texture.image.width, 64);
      expect(texture.image.height, 32);
      expect(texture.width, 32);
      expect(texture.height, 16);

      texture.dispose();
      shape.dispose();
    },
  );

  test('snapshot explicit area is local and exact while attached', () async {
    final root = GRoot();
    final stage = GStage(root)
      ..mount()
      ..setViewport(320, 240);
    final shape = root.addChild(GShape())
      ..x = 120
      ..y = 80
      ..rotation = .4;
    shape.graphics
      ..beginFill(const ui.Color(0xffffffff))
      ..drawRect(0, 0, 40, 30)
      ..endFill();

    final texture = await shape.snapshot(area: GRect(5, 6, 10, 8), scale: 3);
    expect(texture.image.width, 30);
    expect(texture.image.height, 24);
    expect(texture.width, 10);
    expect(texture.height, 8);

    texture.dispose();
    stage.dispose();
  });

  test('detached snapshot resolves masks in the same detached tree', () async {
    final tree = GNode();
    final target = tree.addChild(GShape());
    target.graphics
      ..beginFill(const ui.Color(0xffffffff))
      ..drawRect(0, 0, 20, 10)
      ..endFill();

    final mask = tree.addChild(GShape())..x = 10;
    mask.graphics
      ..beginFill(const ui.Color(0xffffffff))
      ..drawRect(0, 0, 10, 10)
      ..endFill();
    target.mask = mask;

    final texture = await target.snapshot(area: GRect(0, 0, 20, 10));
    final pixels = await texture.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(pixels, isNotNull);

    int alphaAt(int x, int y) => pixels!.getUint8((y * texture.image.width + x) * 4 + 3);

    expect(alphaAt(5, 5), 0);
    expect(alphaAt(15, 5), greaterThan(240));
    expect(target.isAttached, isFalse);
    expect(mask.isAttached, isFalse);

    texture.dispose();
    tree.dispose();
  });

  test(
    'detached viewport group snapshots bypass hosted viewport culling',
    () async {
      final group = GViewportGroup();
      final shape = group.addChild(GShape())..x = 100;
      shape.graphics
        ..beginFill(const ui.Color(0xffffffff))
        ..drawRect(0, 0, 20, 10)
        ..endFill();

      final texture = await group.snapshot(area: GRect(0, 0, 120, 10));
      expect(texture.image.width, 120);
      expect(texture.image.height, 10);
      expect(group.isAttached, isFalse);

      texture.dispose();
      group.dispose();
    },
  );
}
