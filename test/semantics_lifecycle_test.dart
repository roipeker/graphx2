import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets(
    'semantics follows transform visibility and same-stage reparent',
    (tester) async {
      final handle = tester.ensureSemantics();
      final root = GRoot();
      final left = root.addChild(GNode(name: 'left'))..setPosition(20, 30);
      final right = root.addChild(GNode(name: 'right'))..setPosition(160, 70);
      final control = left.addChild(_BoxNode('control'))..setPosition(10, 15);
      control.semantics
        ..label = 'Retained control'
        ..role = GSemanticsRole.button;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: GraphXView(root: () => root),
          ),
        ),
      );
      await tester.pump();

      var node = find.semantics.byLabel('Retained control').evaluate().single;
      final semanticId = node.id;
      expect(node.transform!.entry(0, 3), closeTo(30, 1e-9));
      expect(node.transform!.entry(1, 3), closeTo(45, 1e-9));

      right.addChild(control);
      await tester.pump();
      node = find.semantics.byLabel('Retained control').evaluate().single;
      expect(node.id, semanticId);
      expect(node.transform!.entry(0, 3), closeTo(170, 1e-9));
      expect(node.transform!.entry(1, 3), closeTo(85, 1e-9));

      control.visible = false;
      await tester.pump();
      node = find.semantics.byLabel('Retained control').evaluate().single;
      expect(node.flagsCollection.isHidden, isTrue);

      control.visible = true;
      control.semantics.value = 'Updated';
      await tester.pump();
      node = find.semantics.byLabel('Retained control').evaluate().single;
      expect(node.id, semanticId);
      expect(node.value, 'Updated');
      expect(node.flagsCollection.isHidden, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      handle.dispose();
    },
  );
}

final class _BoxNode extends GNode {
  _BoxNode(String name) : super(name: name);

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, 40, 24);
}
