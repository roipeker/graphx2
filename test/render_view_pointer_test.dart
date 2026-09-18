// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets('same node has distinct hover identity in split render views', (
    tester,
  ) async {
    late GRenderView left;
    late GRenderView right;
    final enters = <GRenderView?>[];
    final exits = <GRenderView?>[];

    await _pump(tester, (root) {
      left = GRenderView(viewport: GRect(0, 0, 100, 160));
      right = GRenderView(viewport: GRect(100, 0, 100, 160));
      root.stage.renderViews
        ..add(left)
        ..add(right);

      final box = root.addChild(_HitBox(80, 80))
        ..x = 10
        ..y = 10;
      box.pointer.onEnter.add((event) => enters.add(event.renderView));
      box.pointer.onExit.add((event) => exits.add(event.renderView));
    });

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(90, 120));
    await mouse.moveTo(const Offset(40, 40));
    await tester.pump();

    expect(enters, <GRenderView?>[left]);
    expect(exits, isEmpty);

    // Same retained node and same world coordinate, but through the other view.
    await mouse.moveTo(const Offset(140, 40));
    await tester.pump();

    expect(exits, <GRenderView?>[left]);
    expect(enters, <GRenderView?>[left, right]);
    await mouse.removePointer();
  });

  testWidgets('stationary hover follows overlapping render-view z order', (
    tester,
  ) async {
    late GStage stage;
    late GRenderView back;
    late GRenderView front;
    final enters = <GRenderView?>[];
    final exits = <GRenderView?>[];

    await _pump(tester, (root) {
      stage = root.stage;
      back = GRenderView(viewport: GRect(0, 0, 100, 100));
      front = GRenderView(viewport: GRect(0, 0, 100, 100));
      stage.renderViews
        ..add(back)
        ..add(front);

      final box = root.addChild(_HitBox(80, 80))
        ..x = 10
        ..y = 10;
      box.pointer.onEnter.add((event) => enters.add(event.renderView));
      box.pointer.onExit.add((event) => exits.add(event.renderView));
    });

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(120, 120));
    await mouse.moveTo(const Offset(40, 40));
    await tester.pump();
    expect(enters, <GRenderView?>[front]);

    // No mouse movement: changing view order must still swap rendered identity.
    stage.renderViews.bringToFront(back);
    await tester.pump();
    await tester.pump();

    expect(exits, <GRenderView?>[front]);
    expect(enters, <GRenderView?>[front, back]);
    await mouse.removePointer();
  });
}

Future<void> _pump(WidgetTester tester, void Function(_Root root) build) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 160,
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
