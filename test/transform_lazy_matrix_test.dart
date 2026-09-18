// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  group('lazy local matrices', () {
    test(
      'identity traversal does not materialize or resolve local matrices',
      () {
        final root = GRoot();
        final stage = GStage(root);
        stage.stats.enabled = true;
        stage.mount();
        final parent = root.addChild(GNode());
        final child = parent.addChild(GNode());
        final out = GPoint();
        final stats = stage.stats.transform;

        child.localToGlobalInto(4, 7, out);

        expect(out.x, 4);
        expect(out.y, 7);
        expect(stats.localMatrixMaterializations.value, 0);
        expect(stats.localMatrixUpdates.value, 0);
        expect(stats.worldMatrixUpdates.value, greaterThanOrEqualTo(3));

        stage.dispose();
      },
    );

    test('identity bounds traversal does not materialize local matrices', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final parent = root.addChild(GNode());
      parent.addChild(_BoundsNode());
      final out = GBounds.empty();
      final stats = stage.stats.transform;

      parent.getLocalBounds(out);

      expect(out.x1, 0);
      expect(out.y1, 0);
      expect(out.x2, 100);
      expect(out.y2, 50);
      expect(stats.localMatrixMaterializations.value, 0);
      expect(stats.localMatrixUpdates.value, 0);

      stage.dispose();
    });

    test('localMatrix getter materializes identity storage on demand', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final node = root.addChild(GNode());
      final stats = stage.stats.transform;

      expect(node.hasLocalTransform, isFalse);
      expect(stats.localMatrixMaterializations.value, 0);
      expect(stats.localMatrixUpdates.value, 0);

      expect(node.localMatrix.isIdentity, isTrue);
      expect(stats.localMatrixMaterializations.value, 1);
      expect(node.localMatrix.isIdentity, isTrue);
      expect(stats.localMatrixMaterializations.value, 1);
      expect(stats.localMatrixUpdates.value, 0);

      stage.dispose();
    });

    test('copyLocalMatrixInto keeps identity node matrix-free', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final node = root.addChild(GNode());
      final out = GMatrix2(2, 3, 4, 5, 6, 7);
      final stats = stage.stats.transform;

      node.copyLocalMatrixInto(out);

      expect(out.isIdentity, isTrue);
      expect(stats.localMatrixMaterializations.value, 0);
      expect(stats.localMatrixUpdates.value, 0);

      stage.dispose();
    });

    test('transformed node materializes and resolves exactly once', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final node = root.addChild(GNode())..x = 20;
      final stats = stage.stats.transform;

      expect(node.hasLocalTransform, isTrue);
      expect(stats.localMatrixMaterializations.value, 1);
      expect(stats.localMatrixUpdates.value, 1);
      expect(node.localMatrix.tx, 20);
      expect(stats.localMatrixMaterializations.value, 1);
      expect(stats.localMatrixUpdates.value, 1);

      node.x = 30;
      expect(node.localMatrix.tx, 30);
      expect(stats.localMatrixMaterializations.value, 1);
      expect(stats.localMatrixUpdates.value, 2);

      stage.dispose();
    });

    test('preserved setPivot keeps an identity node matrix-free', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final node = root.addChild(GNode());
      final stats = stage.stats.transform;

      node.setPivot(20, 30, preserve: true);

      expect(node.x, 20);
      expect(node.y, 30);
      expect(node.pivotX, 20);
      expect(node.pivotY, 30);
      expect(node.hasLocalTransform, isFalse);
      expect(stats.localMatrixMaterializations.value, 0);
      expect(stats.localMatrixUpdates.value, 0);

      stage.dispose();
    });

    test('setPivot preserve keeps a complex matrix unchanged', () {
      final node = GNode();
      node.setPosition(120, 80);
      node.setScale(-1.7, .6);
      node.rotation = .37;
      node.setSkew(.18, -.11);
      final before = GMatrix2()..copyFrom(node.localMatrix);

      node.setPivot(40, -25, preserve: true);

      _expectMatrixClose(node.localMatrix, before);
    });
  });
}

final class _BoundsNode extends GNode {
  @override
  void computeSelfBounds(GBounds out) => out.set(0, 0, 100, 50);
}

void _expectMatrixClose(GMatrix2 actual, GMatrix2 expected) {
  expect(actual.a, closeTo(expected.a, 1e-12));
  expect(actual.b, closeTo(expected.b, 1e-12));
  expect(actual.c, closeTo(expected.c, 1e-12));
  expect(actual.d, closeTo(expected.d, 1e-12));
  expect(actual.tx, closeTo(expected.tx, 1e-12));
  expect(actual.ty, closeTo(expected.ty, 1e-12));
}
