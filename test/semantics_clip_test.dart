// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets('rect clips hide semantics only when fully outside', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final root = GRoot();
    final viewport = root.addChild(GNode(name: 'viewport'))..clip = GClip.rect(0, 0, 100, 100);
    final control = viewport.addChild(_SemanticBox())..y = 120;
    control.semantics
      ..label = 'Clipped control'
      ..role = GSemanticsRole.button;

    await tester.pumpWidget(_host(root));
    await tester.pump();

    final finder = find.semantics.byLabel('Clipped control');
    expect(finder, findsOne);
    expect(finder.evaluate().single.flagsCollection.isHidden, isTrue);

    control.y = 90;
    await tester.pump();
    expect(finder.evaluate().single.flagsCollection.isHidden, isFalse);

    control.y = 20;
    await tester.pump();
    expect(finder.evaluate().single.flagsCollection.isHidden, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });
}

Widget _host(GRoot root) {
  return MaterialApp(
    home: SizedBox(
      width: 240,
      height: 240,
      child: GraphXView(root: () => root),
    ),
  );
}

final class _SemanticBox extends GNode {
  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, 20, 20);
}
