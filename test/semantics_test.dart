// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  group('semantics', () {
    test('semantic state is lazy and annotation stays opt-in', () {
      final node = GNode(name: 'node');

      expect(node.hasSemantics, isFalse);
      final semantics = node.semantics;
      expect(node.hasSemantics, isFalse);

      semantics
        ..label = 'Play'
        ..role = GSemanticsRole.button
        ..enabled = true
        ..selected = false
        ..action(GActions.activate);

      expect(node.hasSemantics, isTrue);
      expect(semantics.label, 'Play');
      expect(semantics.role, GSemanticsRole.button);
      expect(semantics.enabled, isTrue);
      expect(semantics.selected, isFalse);
      expect(semantics.supportsAction(GActions.activate), isTrue);

      semantics.action(GActions.activate, enabled: false);
      expect(semantics.supportsAction(GActions.activate), isFalse);
      expect(node.hasSemantics, isTrue);

      semantics.clear();
      expect(node.hasSemantics, isFalse);

      node.dispose();
    });

    test('merge and exclude descendant policies are mutually exclusive', () {
      final semantics = GNode(name: 'node').semantics;

      semantics.mergeDescendants = true;
      expect(semantics.mergeDescendants, isTrue);
      expect(semantics.excludeDescendants, isFalse);

      semantics.excludeDescendants = true;
      expect(semantics.mergeDescendants, isFalse);
      expect(semantics.excludeDescendants, isTrue);

      semantics.mergeDescendants = true;
      expect(semantics.mergeDescendants, isTrue);
      expect(semantics.excludeDescendants, isFalse);
    });

    test(
      'accessibility action targets semantic node without moving input focus',
      () {
        final root = GRoot();
        final focused = root.addChild(_BoxNode('focused')..focusable = true);
        final parent = root.addChild(GNode(name: 'parent'));
        final target = parent.addChild(_BoxNode('target'));
        final stage = _mount(root);
        final route = <String>[];
        GActionEvent? targetEvent;

        target.onAction.add((event) {
          targetEvent = event;
          route.add('target');
        });
        parent.onAction.add((event) {
          route.add('parent');
          event.handle();
        });

        expect(focused.requestFocus(), isTrue);
        expect(
          stage.actions.dispatchTo(
            target,
            GActions.activate,
            source: GActionSource.accessibility,
          ),
          isTrue,
        );

        expect(route, ['target', 'parent']);
        expect(targetEvent!.target, same(target));
        expect(targetEvent!.source, GActionSource.accessibility);
        expect(stage.focus.focusedNode, same(focused));
        expect(focused.hasFocus, isTrue);
        expect(target.hasFocus, isFalse);

        stage.dispose();
      },
    );

    test('targeted semantic action rejects detached and foreign nodes', () {
      final root = GRoot();
      final attached = root.addChild(_BoxNode('attached'));
      final stage = _mount(root);
      final detached = _BoxNode('detached');
      final otherRoot = GRoot();
      final foreign = otherRoot.addChild(_BoxNode('foreign'));
      final otherStage = _mount(otherRoot);

      expect(stage.actions.dispatchTo(attached, GActions.activate), isFalse);
      expect(stage.actions.dispatchTo(detached, GActions.activate), isFalse);
      expect(stage.actions.dispatchTo(foreign, GActions.activate), isFalse);

      stage.dispose();
      otherStage.dispose();
      detached.dispose();
    });
  });
}

GStage _mount(GRoot root) {
  final stage = GStage(root)..mount();
  stage.setViewport(400, 400);
  return stage;
}

final class _BoxNode extends GNode {
  _BoxNode(String name) : super(name: name);

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, 20, 20);
}
