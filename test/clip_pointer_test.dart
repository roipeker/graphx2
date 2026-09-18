import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets('rect clip rejects pointer hits outside visible subtree', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, (root) {
      final viewport = root.addChild(GNode())..clip = GClip.rect(0, 0, 50, 50);
      final content = viewport.addChild(_HitBox(100, 100));
      content.pointer.onTap.add((_) => taps++);
    });

    await tester.tapAt(const Offset(25, 25));
    await tester.pump();
    expect(taps, 1);

    await tester.tapAt(const Offset(75, 25));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('inverse path clip rejects hits through the retained hole', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, (root) {
      final hole = ui.Path()..addRect(const ui.Rect.fromLTWH(20, 20, 30, 30));
      final viewport = root.addChild(GNode())..clip = GClip.inversePath(hole);
      final content = viewport.addChild(_HitBox(100, 100));
      content.pointer.onTap.add((_) => taps++);
    });

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(taps, 1);

    await tester.tapAt(const Offset(30, 30));
    await tester.pump();
    expect(taps, 1);

    await tester.tapAt(const Offset(70, 70));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('composite pointer target cannot hit through its own clip', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, (root) {
      final control = root.addChild(GNode())..clip = GClip.rect(0, 0, 50, 50);
      control.addChild(_HitBox(100, 100));
      control.pointer
        ..children = false
        ..onTap.add((_) => taps++);
    });

    await tester.tapAt(const Offset(25, 25));
    await tester.pump();
    expect(taps, 1);

    await tester.tapAt(const Offset(75, 25));
    await tester.pump();
    expect(taps, 1);
  });
}

Future<void> _pump(WidgetTester tester, void Function(_Root root) build) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 160,
          height: 120,
          child: GraphXView(
            root: () => _Root(build),
            config: const GraphXConfig(
              hitTestBehavior: GHitTestBehavior.content,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

final class _Root extends GRoot {
  _Root(this.buildScene);

  final void Function(_Root root) buildScene;

  @override
  void attached() => buildScene(this);
}

final class _HitBox extends GNode {
  _HitBox(this.width, this.height);

  final double width;
  final double height;

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, width, height);
}
