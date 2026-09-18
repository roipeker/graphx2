// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  group('GNode transforms', () {
    test(
      'nested world transform converts points without allocations on hot API',
      () {
        final root = GRoot();
        final parent = root.addChild(GNode())
          ..x = 10
          ..y = 20
          ..scaleX = 2
          ..scaleY = 3;
        final child = parent.addChild(GNode())
          ..x = 5
          ..y = 7;

        final out = GPoint();
        child.localToGlobalInto(1, 2, out);
        expect(out.x, 22);
        expect(out.y, 47);

        expect(child.globalToLocalInto(out.x, out.y, out), isTrue);
        expect(out.x, closeTo(1, 1e-12));
        expect(out.y, closeTo(2, 1e-12));
      },
    );

    test('node-space delta conversion ignores translation', () {
      final root = GRoot();
      final source = root.addChild(GNode())..setPosition(100, 200);
      final target = root.addChild(GNode())..setPosition(-50, 70);
      final stage = GStage(root)
        ..mount()
        ..setViewport(100, 100);
      final out = GPoint();

      expect(source.localDeltaToNodeInto(target, 3, 4, out), isTrue);
      expect(out.x, closeTo(3, 1e-12));
      expect(out.y, closeTo(4, 1e-12));

      final allocated = source.localDeltaToNode(target, 5, -2);
      expect(allocated, isNotNull);
      expect(allocated!.x, closeTo(5, 1e-12));
      expect(allocated.y, closeTo(-2, 1e-12));
      stage.dispose();
    });

    test('node-space delta conversion applies rotation scale and skew', () {
      final root = GRoot();
      final source = root.addChild(GNode())
        ..rotation = GMath.halfPi
        ..setScale(2, 3);
      final target = root.addChild(GNode())..setScale(4, 6);
      final stage = GStage(root)
        ..mount()
        ..setViewport(100, 100);
      final out = GPoint();

      expect(source.localDeltaToNodeInto(target, 2, 0, out), isTrue);
      expect(out.x, closeTo(0, 1e-12));
      expect(out.y, closeTo(2 / 3, 1e-12));

      source
        ..rotation = 0
        ..setScale(1)
        ..setSkew(.3, -.2);
      target.setScale(1);
      final expected = GPoint();
      source.localMatrix.transformDeltaInto(2, 3, expected);

      expect(source.localDeltaToNodeInto(target, 2, 3, out), isTrue);
      expect(out.x, closeTo(expected.x, 1e-12));
      expect(out.y, closeTo(expected.y, 1e-12));
      stage.dispose();
    });

    test(
      'node-space delta conversion handles same node singular and cross-Stage',
      () {
        final same = GNode()..scaleX = 0;
        final out = GPoint();
        expect(same.localDeltaToNodeInto(same, 7, -3, out), isTrue);
        expect(out.x, 7);
        expect(out.y, -3);

        final rootA = GRoot();
        final source = rootA.addChild(GNode());
        final singularTarget = rootA.addChild(GNode())..scaleX = 0;
        final stageA = GStage(rootA)
          ..mount()
          ..setViewport(100, 100);
        expect(source.localDeltaToNodeInto(singularTarget, 1, 2, out), isFalse);

        final rootB = GRoot();
        final other = rootB.addChild(GNode());
        final stageB = GStage(rootB)
          ..mount()
          ..setViewport(100, 100);
        expect(source.localDeltaToNodeInto(other, 1, 2, out), isFalse);
        expect(source.localDeltaToNode(other, 1, 2), isNull);

        stageA.dispose();
        stageB.dispose();
      },
    );

    test(
      'matrix inverse delta ignores translation and round-trips vectors',
      () {
        final matrix = GMatrix2(2, 1, -.5, 3, 100, -200);
        final transformed = GPoint();
        final restored = GPoint();

        matrix.transformDeltaInto(4, -2, transformed);
        expect(
          matrix.inverseTransformDeltaInto(
            transformed.x,
            transformed.y,
            restored,
          ),
          isTrue,
        );
        expect(restored.x, closeTo(4, 1e-12));
        expect(restored.y, closeTo(-2, 1e-12));

        matrix
          ..tx = -900
          ..ty = 700;
        expect(
          matrix.inverseTransformDeltaInto(
            transformed.x,
            transformed.y,
            restored,
          ),
          isTrue,
        );
        expect(restored.x, closeTo(4, 1e-12));
        expect(restored.y, closeTo(-2, 1e-12));

        expect(
          GMatrix2(0, 0, 0, 1).inverseTransformDeltaInto(1, 2, restored),
          isFalse,
        );
      },
    );

    test('parent transform changes invalidate descendants lazily', () {
      final root = GRoot();
      final parent = root.addChild(GNode())..x = 10;
      final child = parent.addChild(GNode())..x = 5;
      final out = GPoint();

      child.localToGlobalInto(0, 0, out);
      expect(out.x, 15);

      parent.x = 30;
      child.localToGlobalInto(0, 0, out);
      expect(out.x, 35);
    });

    test('transform helpers batch common scalar mutations', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final node = root.addChild(GNode());
      final invalidations = stage.stats.transform.invalidations;
      final scratch = GMatrix2();

      var before = invalidations.value;
      node.setPosition(10, 20);
      expect(node.x, 10);
      expect(node.y, 20);
      expect(invalidations.value, before + 1);
      node.copyLocalMatrixInto(scratch);

      before = invalidations.value;
      node.scale = 2;
      expect(node.scale, 2);
      expect(node.scaleX, 2);
      expect(node.scaleY, 2);
      expect(invalidations.value, before + 1);
      node.copyLocalMatrixInto(scratch);

      before = invalidations.value;
      node.setScale(3);
      expect(node.scaleX, 3);
      expect(node.scaleY, 3);
      expect(invalidations.value, before + 1);
      node.copyLocalMatrixInto(scratch);

      before = invalidations.value;
      node.setScale(4, 5);
      expect(node.scale, 4);
      expect(node.scaleX, 4);
      expect(node.scaleY, 5);
      expect(invalidations.value, before + 1);
      node.copyLocalMatrixInto(scratch);

      before = invalidations.value;
      node.setSkew(.1, -.2);
      expect(node.skewX, .1);
      expect(node.skewY, -.2);
      expect(invalidations.value, before + 1);

      stage.dispose();
    });

    test('fluent scalar cascades coalesce until the matrix resolves', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final node = root.addChild(GNode());
      final invalidations = stage.stats.transform.invalidations;

      final before = invalidations.value;
      node
        ..x = 10
        ..y = 20
        ..rotation = .3
        ..scaleX = 2
        ..scaleY = 3;

      expect(invalidations.value, before + 1);
      expect(node.x, 10);
      expect(node.y, 20);
      expect(node.rotation, .3);
      expect(node.scaleX, 2);
      expect(node.scaleY, 3);
      expect(node.localMatrix.tx, closeTo(10, 1e-12));
      expect(node.localMatrix.ty, closeTo(20, 1e-12));

      final afterResolve = invalidations.value;
      node
        ..x = 11
        ..y = 21;
      expect(invalidations.value, afterResolve + 1);

      stage.dispose();
    });

    test('alignPivot preserves the complete local transform by default', () {
      final node = _BoundsNode(10, 20, 110, 70);
      node.setPosition(120, 80);
      node.setScale(-1.7, .6);
      node.rotation = .37;
      node.setSkew(.18, -.11);

      final before = GMatrix2()..copyFrom(node.localMatrix);

      node.alignPivot(0, 0);

      expect(node.pivotX, 60);
      expect(node.pivotY, 45);
      _expectMatrixClose(node.localMatrix, before);
    });

    test('preserved alignPivot leaves transform caches clean', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final node = root.addChild(_BoundsNode(0, 0, 100, 50));
      node.setPosition(20, 30);
      node.setScale(-2, .75);
      node.rotation = .4;
      node.setSkew(.1, -.2);

      final point = GPoint();
      node.localToGlobalInto(0, 0, point);
      final before = GMatrix2()..copyFrom(node.localMatrix);
      final stats = stage.stats.transform;
      final invalidations = stats.invalidations.value;
      final localUpdates = stats.localMatrixUpdates.value;
      final worldUpdates = stats.worldMatrixUpdates.value;

      node.alignPivot(0, 0);

      expect(stats.invalidations.value, invalidations);
      expect(stats.localMatrixUpdates.value, localUpdates);
      _expectMatrixClose(node.localMatrix, before);
      node.localToGlobalInto(0, 0, point);
      expect(stats.worldMatrixUpdates.value, worldUpdates);

      stage.dispose();
    });

    test('alignPivot can change registration without compensation', () {
      final node = _BoundsNode(10, 20, 110, 70);
      node.setPosition(20, 30);

      node.alignPivot(-1, -1, preserve: false);

      expect(node.pivotX, 10);
      expect(node.pivotY, 20);
      expect(node.x, 20);
      expect(node.y, 30);
      expect(node.localMatrix.tx, 10);
      expect(node.localMatrix.ty, 10);
    });

    test('alignPivot uses current subtree local bounds', () {
      final parent = GNode();
      final child = parent.addChild(_BoundsNode(0, 0, 100, 50));
      child.setPosition(20, 30);

      parent.alignPivot(0, 0, preserve: false);

      expect(parent.pivotX, 70);
      expect(parent.pivotY, 55);
    });

    test('alignPivot ignores empty bounds', () {
      final node = GNode()
        ..pivotX = 3
        ..pivotY = 4;

      node.alignPivot(0, 0);

      expect(node.pivotX, 3);
      expect(node.pivotY, 4);
    });

    test('local matrix assignment copies and canonicalizes scalar state', () {
      final node = GNode();
      final source = GMatrix2(2, 1, -3, 4, 20, 30);

      node.localMatrix = source;
      source.identity();

      expect(node.localMatrix.a, 2);
      expect(node.localMatrix.b, 1);
      expect(node.localMatrix.c, -3);
      expect(node.localMatrix.d, 4);
      expect(node.x, 20);
      expect(node.y, 30);
      expect(node.pivotX, 0);
      expect(node.pivotY, 0);

      // Mutating a scalar after matrix assignment remains deterministic because
      // assignment canonicalizes the matrix into GraphX's scalar transform.
      node.x = 40;
      expect(node.localMatrix.tx, 40);
      expect(node.localMatrix.ty, 30);
      expect(node.localMatrix.a, closeTo(2, 1e-12));
      expect(node.localMatrix.b, closeTo(1, 1e-12));
      expect(node.localMatrix.c, closeTo(-3, 1e-12));
      expect(node.localMatrix.d, closeTo(4, 1e-12));
    });

    test('matrix values can be assigned without a temporary matrix', () {
      final node = GNode();
      node.setLocalMatrixValues(1, 0, 0, 1, 12, 34);
      expect(node.x, 12);
      expect(node.y, 34);
      expect(node.localMatrix.tx, 12);
      expect(node.localMatrix.ty, 34);
    });

    test('singular world transform cannot convert global to local', () {
      final node = GNode()..scaleX = 0;
      final out = GPoint();
      expect(node.globalToLocalInto(10, 10, out), isFalse);
      expect(node.globalToLocal(10, 10), isNull);
    });

    test('transform stats are optional and expose cache behavior', () {
      final root = GRoot();
      final stage = GStage(root);
      stage.stats.enabled = true;
      stage.mount();
      final child = root.addChild(GNode())..x = 10;
      final out = GPoint();

      child.localToGlobalInto(0, 0, out);
      child.localToGlobalInto(1, 1, out);

      final stats = stage.stats.transform;
      expect(stats.localMatrixUpdates.value, greaterThanOrEqualTo(1));
      expect(stats.worldMatrixUpdates.value, greaterThanOrEqualTo(1));
      expect(stats.worldMatrixCacheHits.value, greaterThanOrEqualTo(1));
      expect(stats.localToGlobal.value, 2);

      stage.dispose();
    });
  });
}

final class _BoundsNode extends GNode {
  _BoundsNode(this._x1, this._y1, this._x2, this._y2);

  final double _x1;
  final double _y1;
  final double _x2;
  final double _y2;

  @override
  void computeSelfBounds(GBounds out) => out.set(_x1, _y1, _x2, _y2);
}

void _expectMatrixClose(GMatrix2 actual, GMatrix2 expected) {
  expect(actual.a, closeTo(expected.a, 1e-12));
  expect(actual.b, closeTo(expected.b, 1e-12));
  expect(actual.c, closeTo(expected.c, 1e-12));
  expect(actual.d, closeTo(expected.d, 1e-12));
  expect(actual.tx, closeTo(expected.tx, 1e-12));
  expect(actual.ty, closeTo(expected.ty, 1e-12));
}
