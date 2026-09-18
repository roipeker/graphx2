import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('pointer defaults are enabled with child targeting', () {
    final node = GNode();
    expect(node.pointer.enabled, isTrue);
    expect(node.pointer.children, isTrue);
  });

  testWidgets('root node pointer stays separate from stage pointer manager', (
    tester,
  ) async {
    late GRoot root;
    await _pump(tester, (scene) => root = scene);

    expect(root.pointer, isA<GNodePointer>());
    expect(root.stage.pointer, isA<GPointerManager>());
    expect(root.stage.pointer.panZoom, isA<GPointerPanZoomState>());

    root.stage.pointer.onPanZoomStart;
    root.stage.pointer.onPanZoomUpdate;
    root.stage.pointer.onPanZoomEnd;
  });

  testWidgets('bubbles leaf target and supports composite children=false', (
    tester,
  ) async {
    late GNode parent;
    late GNode child;
    final targets = <GNode>[];

    await _pump(tester, (root) {
      parent = root.addChild(GNode());
      child = parent.addChild(_HitBox(80, 50))
        ..x = 20
        ..y = 20;
      parent.pointer.onDown.add((e) => targets.add(e.target));
    });
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(targets.single, same(child));

    targets.clear();
    parent.pointer.children = false;
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(targets.single, same(parent));
  });

  testWidgets('enabled false gates and restores a subtree', (tester) async {
    late GNode panel;
    var downs = 0;
    await _pump(tester, (root) {
      panel = root.addChild(GNode());
      final child = panel.addChild(_HitBox(80, 50))
        ..x = 20
        ..y = 20;
      child.pointer.onDown.add((_) => downs++);
      panel.pointer.enabled = false;
    });
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(downs, 0);
    panel.pointer.enabled = true;
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(downs, 1);
  });

  testWidgets('custom hit area overrides pointer geometry only', (
    tester,
  ) async {
    late _HitBox box;
    var downs = 0;
    await _pump(tester, (root) {
      box = root.addChild(_HitBox(20, 20))
        ..x = 50
        ..y = 50;
      box.hitArea = GHitArea.circle(10, 10, 35);
      box.pointer.onDown.add((_) => downs++);
    });

    // Outside visual 20x20 geometry but inside the larger pointer circle.
    await tester.tapAt(const Offset(30, 60));
    await tester.pump();
    expect(downs, 1);

    // Visual inspection remains truthful to rendered geometry.
    expect(box.hitTest(30, 60), isNull);
    expect(box.hitTest(55, 55), same(box));
  });

  testWidgets('path stroke hit area follows nested affine transforms', (
    tester,
  ) async {
    late GNode target;
    var downs = 0;

    await _pump(tester, (root) {
      final parent = root.addChild(GNode())
        ..x = 90
        ..y = 70
        ..rotation = .18
        ..setSkew(.08, -.05);
      target = parent.addChild(GNode())
        ..x = 25
        ..y = 5
        ..setScale(-.9, .8)
        ..rotation = -.25
        ..setSkew(.1, -.12);
      target.hitArea = GHitArea.pathStroke(
        Path()
          ..moveTo(0, 0)
          ..lineTo(60, 0),
        16,
      );
      target.pointer.onDown.add((_) => downs++);
    });

    final point = GPoint();
    target.localToGlobalInto(30, 4, point);
    await tester.tapAt(Offset(point.x, point.y));
    await tester.pump();
    expect(downs, 1);

    target.localToGlobalInto(30, 12, point);
    await tester.tapAt(Offset(point.x, point.y));
    await tester.pump();
    expect(downs, 1);
  });

  testWidgets('Graphics stroke hit area follows nested affine transforms', (
    tester,
  ) async {
    late GShape target;
    var downs = 0;

    await _pump(tester, (root) {
      final parent = root.addChild(GNode())
        ..x = 90
        ..y = 80
        ..rotation = -.12
        ..setSkew(.06, -.04);
      target = parent.addChild(GShape())
        ..x = 10
        ..setScale(1.1, -.8)
        ..rotation = .22
        ..setSkew(-.08, .1);
      target.graphics
        ..lineStyle(2, const Color(0xffffffff))
        ..drawLine(0, 0, 60, 0);
      target.hitArea = target.graphics.strokeHitArea(16);
      target.pointer.onDown.add((_) => downs++);
    });

    final point = GPoint();
    target.localToGlobalInto(30, 6, point);
    await tester.tapAt(Offset(point.x, point.y));
    await tester.pump();
    expect(downs, 1);

    target.localToGlobalInto(30, 12, point);
    await tester.tapAt(Offset(point.x, point.y));
    await tester.pump();
    expect(downs, 1);
  });

  testWidgets('explicit composite hit area is authoritative', (tester) async {
    late GNode button;
    var downs = 0;
    await _pump(tester, (root) {
      button = root.addChild(GNode())
        ..x = 20
        ..y = 20;
      button.addChild(_HitBox(120, 50));
      button.pointer.children = false;
      button.hitArea = GHitArea.rect(0, 0, 40, 40);
      button.pointer.onDown.add((_) => downs++);
    });

    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(downs, 1);

    await tester.tapAt(const Offset(100, 40));
    await tester.pump();
    expect(downs, 1);
  });

  testWidgets('rollover follows moving geometry without a moving mouse', (
    tester,
  ) async {
    late GNode box;
    var enters = 0;
    var exits = 0;
    await _pump(tester, (root) {
      box = root.addChild(_HitBox(60, 40))
        ..x = 20
        ..y = 20;
      box.pointer.onEnter.add((_) => enters++);
      box.pointer.onExit.add((_) => exits++);
    });

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(150, 120));
    await mouse.moveTo(const Offset(40, 40));
    await tester.pump();
    expect(enters, 1);
    box.x = 120;
    await tester.pump();
    expect(exits, 1);
    await mouse.removePointer();
  });

  testWidgets('pointer listeners, gates and hit areas do not dirty stage', (
    tester,
  ) async {
    late GStage stage;
    late GNode node;
    await _pump(tester, (root) {
      stage = root.stage;
      node = root.addChild(_HitBox(40, 40));
    });
    await tester.pump();
    expect(stage.needsPaint, isFalse);
    expect(stage.wantsUpdate, isFalse);
    final sub = node.pointer.onDown.add((_) {});
    node.pointer.children = false;
    node.hitArea = GHitArea.rect(-10, -10, 60, 60);
    node.pointer.enabled = false;
    expect(stage.needsPaint, isFalse);
    expect(stage.wantsUpdate, isFalse);
    sub.cancel();
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
