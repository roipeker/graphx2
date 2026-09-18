import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  group('focus', () {
    test('uses scene order and keeps advanced state optional', () {
      final root = GRoot();
      final a = root.addChild(_BoxNode('a')..focusable = true);
      final group = root.addChild(GNode('group'));
      final b = group.addChild(_BoxNode('b')..focusable = true);
      final c = root.addChild(_BoxNode('c')..focusable = true);
      final stage = _mount(root);

      expect(stage.focus.focusedNode, isNull);
      expect(stage.focus.next(), isTrue);
      expect(stage.focus.focusedNode, same(a));
      expect(stage.focus.next(), isTrue);
      expect(stage.focus.focusedNode, same(b));
      expect(stage.focus.next(), isTrue);
      expect(stage.focus.focusedNode, same(c));
      expect(stage.focus.previous(), isTrue);
      expect(stage.focus.focusedNode, same(b));

      b.focus.skipTraversal = true;
      expect(a.requestFocus(), isTrue);
      expect(stage.focus.next(), isTrue);
      expect(stage.focus.focusedNode, same(c));

      // Programmatic focus is intentionally independent from traversal policy.
      expect(b.requestFocus(), isTrue);
      expect(stage.focus.focusedNode, same(b));

      stage.dispose();
    });

    test('repairs focus when node or ancestry becomes ineligible', () {
      final root = GRoot();
      final group = root.addChild(GNode('group'));
      final child = group.addChild(_BoxNode('child')..focusable = true);
      final stage = _mount(root);

      expect(child.requestFocus(), isTrue);
      expect(child.hasFocus, isTrue);
      expect(group.hasFocusWithin, isTrue);

      group.visible = false;
      expect(stage.focus.focusedNode, isNull);

      group.visible = true;
      expect(child.requestFocus(), isTrue);
      group.active = false;
      expect(stage.focus.focusedNode, isNull);

      group.active = true;
      expect(child.requestFocus(), isTrue);
      child.focusable = false;
      expect(stage.focus.focusedNode, isNull);
      expect(child.requestFocus(), isFalse);

      stage.dispose();
    });

    test(
      'preserves focus and repairs focus-within across same-stage reparent',
      () {
        final root = GRoot();
        final left = root.addChild(GNode('left'));
        final right = root.addChild(GNode('right'));
        final child = left.addChild(_BoxNode('child')..focusable = true);
        final stage = _mount(root);
        final leftWithin = <bool>[];
        final rightWithin = <bool>[];
        left.onFocusWithinChanged.add(leftWithin.add);
        right.onFocusWithinChanged.add(rightWithin.add);

        expect(child.requestFocus(), isTrue);
        expect(leftWithin, [true]);
        expect(rightWithin, isEmpty);

        right.addChild(child);
        expect(stage.focus.focusedNode, same(child));
        expect(child.hasFocus, isTrue);
        expect(leftWithin, [true, false]);
        expect(rightWithin, [true]);

        right.removeChild(child);
        expect(stage.focus.focusedNode, isNull);
        expect(rightWithin, [true, false]);

        stage.dispose();
      },
    );

    test('emits focus and focus-within changes only on changed paths', () {
      final root = GRoot();
      final parent = root.addChild(GNode('parent'));
      final a = parent.addChild(_BoxNode('a')..focusable = true);
      final b = parent.addChild(_BoxNode('b')..focusable = true);
      final outside = root.addChild(_BoxNode('outside')..focusable = true);
      final stage = _mount(root);

      final aChanges = <bool>[];
      final bChanges = <bool>[];
      final parentWithin = <bool>[];
      a.onFocusChanged.add(aChanges.add);
      b.onFocusChanged.add(bChanges.add);
      parent.onFocusWithinChanged.add(parentWithin.add);

      a.requestFocus();
      b.requestFocus();
      outside.requestFocus();

      expect(aChanges, [true, false]);
      expect(bChanges, [true, false]);
      expect(parentWithin, [true, false]);

      stage.dispose();
    });

    test('routes semantic actions from focused node through ancestors', () {
      final root = GRoot();
      final parent = root.addChild(GNode('parent'));
      final child = parent.addChild(_BoxNode('child')..focusable = true);
      final stage = _mount(root);
      const save = GAction('save');
      final route = <String>[];

      child.onAction.add((event) {
        route.add('child:${event.currentTarget!.name}');
      });
      parent.onAction.add((event) {
        route.add('parent:${event.currentTarget!.name}');
        event.handle();
      });
      root.onAction.add((event) => route.add('root'));

      child.requestFocus();
      expect(stage.actions.dispatch(save), isTrue);
      expect(route, ['child:child', 'parent:parent']);

      stage.dispose();
    });

    test(
      'focus actions use navigation only when user code leaves them unhandled',
      () {
        final root = GRoot();
        final a = root.addChild(_BoxNode('a')..focusable = true);
        final b = root.addChild(_BoxNode('b')..focusable = true);
        final stage = _mount(root);

        a.requestFocus();
        final block = a.onAction.add((event) {
          if (event.action == GActions.focusNext) event.handle();
        });
        expect(stage.actions.dispatch(GActions.focusNext), isTrue);
        expect(stage.focus.focusedNode, same(a));

        block.cancel();
        expect(stage.actions.dispatch(GActions.focusNext), isTrue);
        expect(stage.focus.focusedNode, same(b));

        stage.dispose();
      },
    );

    test(
      'directional traversal uses world geometry and explicit overrides win',
      () {
        final root = GRoot();
        final center = root.addChild(
          _BoxNode('center')
            ..focusable = true
            ..x = 100
            ..y = 100,
        );
        final left = root.addChild(
          _BoxNode('left')
            ..focusable = true
            ..x = 20
            ..y = 100,
        );
        final right = root.addChild(
          _BoxNode('right')
            ..focusable = true
            ..x = 180
            ..y = 100,
        );
        final down = root.addChild(
          _BoxNode('down')
            ..focusable = true
            ..x = 100
            ..y = 180,
        );
        final stage = _mount(root);

        center.requestFocus();
        expect(stage.focus.move(GFocusDirection.right), isTrue);
        expect(stage.focus.focusedNode, same(right));

        center.requestFocus();
        expect(stage.focus.move(GFocusDirection.left), isTrue);
        expect(stage.focus.focusedNode, same(left));

        center.requestFocus();
        expect(stage.focus.move(GFocusDirection.down), isTrue);
        expect(stage.focus.focusedNode, same(down));

        center.focus.right = down;
        center.requestFocus();
        expect(stage.focus.move(GFocusDirection.right), isTrue);
        expect(stage.focus.focusedNode, same(down));

        stage.dispose();
      },
    );
  });
}

GStage _mount(GRoot root) {
  final stage = GStage(root)..mount();
  stage.setViewport(400, 400);
  return stage;
}

final class _BoxNode extends GNode {
  _BoxNode(String name) : super(name);

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, 20, 20);
}
