// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  group('GNode structure', () {
    test('child accessors avoid allocating children snapshots', () {
      final parent = GNode();
      final a = parent.addChild(GNode(name: 'a'));
      final b = parent.addChild(GNode(name: 'b'));

      expect(parent.numChildren, 2);
      expect(parent.getChildAt(0), same(a));
      expect(parent.getChildAt(1), same(b));
      expect(parent.getChildIndex(a), 0);
      expect(parent.getChildIndex(b), 1);
      expect(parent.getChildIndex(GNode()), -1);
      expect(parent.getChildByName('b'), same(b));
      expect(parent.getChildByName('missing'), isNull);
    });

    test('children snapshots are cached until structure changes', () {
      final parent = GNode();
      final a = parent.addChild(GNode());
      final b = parent.addChild(GNode());

      final first = parent.children;
      expect(parent.children, same(first));
      expect(first, [a, b]);

      parent.addChild(a);
      final reordered = parent.children;
      expect(reordered, isNot(same(first)));
      expect(first, [a, b]);
      expect(reordered, [b, a]);

      parent.removeChild(a);
      final removed = parent.children;
      expect(removed, isNot(same(reordered)));
      expect(reordered, [b, a]);
      expect(removed, [b]);
    });

    test('same-stage reparent preserves attachment lifecycle', () {
      final root = GRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(100, 100);
      final a = root.addChild(GNode(name: 'a'));
      final b = root.addChild(GNode(name: 'b'));
      final child = a.addChild(_LifecycleNode('child'));

      expect(child.attachedCount, 1);
      expect(child.detachedCount, 0);
      expect(child.stage, same(stage));

      b.addChild(child);

      expect(child.parent, same(b));
      expect(child.stage, same(stage));
      expect(child.attachedCount, 1);
      expect(child.detachedCount, 0);
      expect(a.numChildren, 0);
      expect(b.getChildAt(0), same(child));

      stage.dispose();
    });

    test('re-adding a child moves it to the front without lifecycle churn', () {
      final root = GRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(100, 100);
      final parent = root.addChild(GNode());
      final a = parent.addChild(_LifecycleNode('a'));
      final b = parent.addChild(_LifecycleNode('b'));

      parent.addChild(a);

      expect(parent.getChildAt(0), same(b));
      expect(parent.getChildAt(1), same(a));
      expect(a.attachedCount, 1);
      expect(a.detachedCount, 0);

      stage.dispose();
    });

    test('cross-stage reparent performs one detach and one attach', () {
      final rootA = GRoot();
      final rootB = GRoot();
      final stageA = GStage(rootA)
        ..mount()
        ..setViewport(100, 100);
      final stageB = GStage(rootB)
        ..mount()
        ..setViewport(100, 100);
      final parentA = rootA.addChild(GNode());
      final parentB = rootB.addChild(GNode());
      final child = parentA.addChild(_LifecycleNode());

      parentB.addChild(child);

      expect(child.stage, same(stageB));
      expect(child.attachedCount, 2);
      expect(child.detachedCount, 1);
      expect(parentA.numChildren, 0);
      expect(parentB.getChildAt(0), same(child));

      stageA.dispose();
      stageB.dispose();
    });

    test(
      'disposing a subtree detaches descendants once and clears ownership',
      () {
        final root = GRoot();
        final stage = GStage(root)
          ..mount()
          ..setViewport(100, 100);
        final parent = root.addChild(GNode());
        final child = parent.addChild(_LifecycleNode('child'));
        final grandchild = child.addChild(_LifecycleNode('grandchild'));

        parent.dispose();

        expect(parent.isDisposed, isTrue);
        expect(child.isDisposed, isTrue);
        expect(grandchild.isDisposed, isTrue);
        expect(parent.parent, isNull);
        expect(child.parent, isNull);
        expect(grandchild.parent, isNull);
        expect(child.detachedCount, 1);
        expect(grandchild.detachedCount, 1);
        expect(root.numChildren, 0);

        stage.dispose();
      },
    );

    test('dispose signal is terminal and post-order for attached subtrees', () {
      final root = GRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(100, 100);
      final parent = root.addChild(GNode(name: 'parent'));
      final child = parent.addChild(GNode(name: 'child'));
      final events = <String>[];

      child.signals.onDetached.add(() {
        expect(child.isDisposed, isFalse);
        expect(child.parent, same(parent));
        expect(child.isAttached, isTrue);
        events.add('child-detached');
      });
      parent.signals.onDetached.add(() {
        expect(parent.isDisposed, isTrue);
        expect(parent.parent, same(root));
        expect(parent.isAttached, isTrue);
        expect(child.isAttached, isFalse);
        events.add('parent-detached');
      });
      child.signals.onDispose.add(() => events.add('child-dispose'));
      parent.signals.onDispose.add(() {
        expect(parent.isDisposed, isTrue);
        expect(parent.parent, isNull);
        expect(parent.isAttached, isFalse);
        expect(child.isDisposed, isTrue);
        events.add('parent-dispose');
      });

      parent.dispose();
      parent.dispose();

      expect(events, [
        'child-detached',
        'parent-detached',
        'child-dispose',
        'parent-dispose',
      ]);
      expect(parent.signals.isDisposed, isTrue);
      stage.dispose();
    });

    test('dispose signal fires exactly once for an already-detached node', () {
      final node = GNode();
      var calls = 0;
      final signal = node.signals.onDispose;
      signal.add(() {
        calls++;
        expect(node.isDisposed, isTrue);
        expect(node.parent, isNull);
        expect(node.isAttached, isFalse);
      });

      node.dispose();
      node.dispose();

      expect(calls, 1);
      expect(signal.isDisposed, isTrue);
      expect(node.signals.isDisposed, isTrue);
    });

    test('adding an ancestor below its descendant is rejected', () {
      final root = GNode();
      final child = root.addChild(GNode());
      final grandchild = child.addChild(GNode());

      expect(() => grandchild.addChild(root), throwsArgumentError);
      expect(root.parent, isNull);
      expect(child.parent, same(root));
      expect(grandchild.parent, same(child));
    });

    test('disposed nodes cannot be reattached', () {
      final parent = GNode();
      final child = GNode()..dispose();

      expect(() => parent.addChild(child), throwsStateError);
      expect(parent.numChildren, 0);
      expect(child.parent, isNull);
    });

    test('disposed parents reject new children', () {
      final parent = GNode()..dispose();
      final child = GNode();

      expect(() => parent.addChild(child), throwsStateError);
      expect(parent.numChildren, 0);
      expect(child.parent, isNull);
    });
  });
}

final class _LifecycleNode extends GNode {
  _LifecycleNode([String? name]) : super(name: name);

  int attachedCount = 0;
  int detachedCount = 0;

  @override
  void attached() {
    attachedCount++;
  }

  @override
  void detached() {
    detachedCount++;
  }
}
