import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets('pointer onTap is synthesized lazily and rejects movement', (
    tester,
  ) async {
    late GNode box;
    var taps = 0;
    await _pump(tester, (root) {
      box = root.addChild(_HitBox(80, 50))
        ..x = 20
        ..y = 20;
      box.pointer.onTap.add((_) => taps++);
    });

    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(taps, 1);

    final gesture = await tester.startGesture(const Offset(40, 40));
    await gesture.moveTo(const Offset(70, 40));
    await gesture.up();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('GDrag starts after slop and keeps the press target', (
    tester,
  ) async {
    late GDrag drag;
    var starts = 0;
    var updates = 0;
    var ends = 0;
    var totalX = 0.0;

    await _pump(tester, (root) {
      final box = root.addChild(_HitBox(40, 40))
        ..x = 20
        ..y = 20;
      drag = GDrag(box, slop: 8);
      drag.onStart.add((_) => starts++);
      drag.onUpdate.add((event) {
        updates++;
        totalX = event.totalDeltaX;
      });
      drag.onEnd.add((_) => ends++);
    });

    final gesture = await tester.startGesture(const Offset(30, 30));
    await gesture.moveTo(const Offset(35, 30));
    expect(starts, 0);

    await gesture.moveTo(const Offset(45, 30));
    expect(starts, 1);
    expect(updates, 1);

    // Move outside the original 40x40 hit box. Press capture keeps routing.
    await gesture.moveTo(const Offset(120, 30));
    await gesture.up();
    expect(starts, 1);
    expect(updates, 2);
    expect(ends, 1);
    expect(totalX, 90);

    drag.dispose();
  });

  testWidgets('GLongPress fires once and movement cancels it', (tester) async {
    late GLongPress press;
    var count = 0;
    await _pump(tester, (root) {
      final box = root.addChild(_HitBox(80, 50))
        ..x = 20
        ..y = 20;
      press = GLongPress(box, delay: const Duration(milliseconds: 300));
      press.onLongPress.add((_) => count++);
    });

    var gesture = await tester.startGesture(const Offset(40, 40));
    await tester.pump(const Duration(milliseconds: 320));
    expect(count, 1);
    await gesture.up();

    gesture = await tester.startGesture(const Offset(40, 40));
    await gesture.moveTo(const Offset(70, 40));
    await tester.pump(const Duration(milliseconds: 320));
    expect(count, 1);
    await gesture.up();

    press.dispose();
  });

  testWidgets('startDrag uses parent-space bounds under transforms', (
    tester,
  ) async {
    late GNode box;
    await _pump(tester, (root) {
      final parent = root.addChild(GNode())
        ..x = 20
        ..scale = 2;
      box = parent.addChild(_HitBox(30, 30))
        ..x = 10
        ..y = 10;
      box.pointer.onDown.add((_) {
        box.startDrag(bounds: GBounds(0, 0, 40, 40));
      });
      box.pointer.onUp.add((_) => box.stopDrag());
    });

    final gesture = await tester.startGesture(const Offset(50, 30));
    await gesture.moveTo(const Offset(110, 90));
    expect(box.x, 40);
    expect(box.y, 40);
    await gesture.up();
    expect(box.isDragging, isFalse);
  });

  testWidgets('startDrag lockCenter is explicit and survives pointer up', (
    tester,
  ) async {
    late GNode box;
    await _pump(tester, (root) {
      box = root.addChild(_HitBox(40, 40))
        ..x = 20
        ..y = 20;
      box.pointer.onDown.add((_) => box.startDrag(lockCenter: true));
    });

    final gesture = await tester.startGesture(const Offset(30, 30));
    expect(box.x, 30);
    expect(box.y, 30);
    expect(box.isDragging, isTrue);

    await gesture.up();
    expect(box.isDragging, isTrue);
    box.stopDrag();
    expect(box.isDragging, isFalse);
  });

  test('node-bound recognizers dispose with node but survive detach', () {
    final parent = GNode();
    final node = parent.addChild(GNode());
    final drag = GDrag(node);
    final longPress = GLongPress(node);

    parent.removeChild(node);
    expect(node.isDisposed, isFalse);
    expect(drag.isDisposed, isFalse);
    expect(longPress.isDisposed, isFalse);

    node.dispose();
    expect(drag.isDisposed, isTrue);
    expect(longPress.isDisposed, isTrue);

    // Owner-driven and explicit disposal can safely interleave.
    drag.dispose();
    longPress.dispose();
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
