import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('cursor defaults stay in the pointer domain', () {
    final node = GNode();
    expect(node.pointer.cursor, isNull);
  });

  testWidgets('node cursor inherits and restores stage cursor', (tester) async {
    late GStage stage;
    late GNode parent;
    late GNode child;

    await _pump(tester, (root) {
      stage = root.stage;
      stage.pointer.cursor = GCursor.text;

      parent = root.addChild(GNode())
        ..x = 20
        ..y = 20;
      parent.pointer.cursor = GCursor.move;
      parent.addChild(_HitBox(100, 80));

      child = parent.addChild(_HitBox(30, 30))
        ..x = 10
        ..y = 10;
      child.pointer.cursor = GCursor.click;
    });

    const pointer = 42;
    const device = 1;
    final mouse = await tester.createGesture(
      pointer: pointer,
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(180, 140));
    await tester.pump();
    expect(_activeCursor(device), SystemMouseCursors.text);

    await mouse.moveTo(const Offset(80, 80));
    await tester.pump();
    expect(_activeCursor(device), SystemMouseCursors.move);

    await mouse.moveTo(const Offset(40, 40));
    await tester.pump();
    expect(_activeCursor(device), SystemMouseCursors.click);

    child.pointer.cursor = null;
    await _settleCursor(tester);
    expect(_activeCursor(device), SystemMouseCursors.move);

    parent.pointer.cursor = null;
    await _settleCursor(tester);
    expect(_activeCursor(device), SystemMouseCursors.text);

    parent.pointer.cursor = GCursor.grab;
    await _settleCursor(tester);
    expect(_activeCursor(device), SystemMouseCursors.grab);

    await mouse.moveTo(const Offset(240, 200));
    await tester.pump();
    expect(_activeCursor(device), SystemMouseCursors.basic);
    await mouse.removePointer();
  });

  testWidgets('cursor changes do not dirty or tick the stage', (tester) async {
    late GStage stage;
    late GNode node;

    await _pump(tester, (root) {
      stage = root.stage;
      node = root.addChild(_HitBox(40, 40));
    });
    await tester.pump();

    expect(stage.needsPaint, isFalse);
    expect(stage.wantsUpdate, isFalse);

    stage.pointer.cursor = GCursor.text;
    node.pointer.cursor = GCursor.click;

    expect(stage.needsPaint, isFalse);
    expect(stage.wantsUpdate, isFalse);
  });
}

MouseCursor? _activeCursor(int device) =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(device);

Future<void> _settleCursor(WidgetTester tester) async {
  // Node cursor changes reconcile after the current dispatch, then Flutter's
  // MouseTracker observes the updated annotation on the following frame.
  await tester.pump();
  await tester.pump();
}

Future<void> _pump(WidgetTester tester, void Function(_Root root) build) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 160,
          child: GraphxView(
            root: () => _Root(build),
            config: const GraphxConfig(
              hitTestBehavior: GHitTestBehavior.opaque,
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
