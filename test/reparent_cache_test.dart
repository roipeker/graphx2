// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test(
    'reparent invalidates parent bounds and lazily refreshes world matrices',
    () {
      final root = GRoot();
      final stage = GStage(root);
      stage.mount();
      stage.setViewport(400, 300);

      final a = root.addChild(GNode(name: 'a'))..x = 10;
      final b = root.addChild(GNode(name: 'b'))..x = 100;
      final child = a.addChild(GNode(name: 'child'))..x = 5;
      child.addChild(_Box(20, 10)).x = 2;
      final grandchild = child.addChild(_Box(4, 4))..x = 30;

      final aBounds = GBounds.empty();
      final bBounds = GBounds.empty();
      a.getLocalBounds(aBounds);
      b.getLocalBounds(bBounds);
      expect((aBounds.x1, aBounds.x2), (7, 39));
      expect(bBounds.isEmpty, isTrue);

      expect(child.localToGlobal(0, 0).x, 15);
      expect(grandchild.localToGlobal(0, 0).x, 45);

      b.addChild(child);

      a.getLocalBounds(aBounds);
      b.getLocalBounds(bBounds);
      expect(aBounds.isEmpty, isTrue);
      expect((bBounds.x1, bBounds.x2), (7, 39));
      expect(child.localToGlobal(0, 0).x, 105);
      expect(grandchild.localToGlobal(0, 0).x, 135);

      stage.dispose();
    },
  );
}

final class _Box extends GNode {
  _Box(this.width, this.height);

  final double width;
  final double height;

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, width, height);
}
