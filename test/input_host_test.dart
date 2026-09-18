import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('external host pointer ingress uses the canonical input pipeline', () {
    final stage = GStage(GRoot())
      ..mount()
      ..setViewport(320, 240);
    addTearDown(stage.dispose);

    final types = <GPointerEventType>[];
    stage.pointer.onEvent.add((event) => types.add(event.type));

    stage.input.dispatchPointer(
      const GPointerEvent(
        type: GPointerEventType.down,
        pointer: 7,
        kind: GPointerDeviceKind.touch,
        x: 40,
        y: 55,
        deltaX: 0,
        deltaY: 0,
        button: 1,
        buttons: 1,
        timestamp: Duration(milliseconds: 10),
      ),
    );

    expect(stage.pointer.x, 40);
    expect(stage.pointer.y, 55);
    expect(stage.pointer.isDown, isTrue);
    expect(stage.pointer.pointer(7)?.down, isTrue);
    expect(types, [GPointerEventType.down]);

    stage.input.dispatchPointer(
      const GPointerEvent(
        type: GPointerEventType.up,
        pointer: 7,
        kind: GPointerDeviceKind.touch,
        x: 44,
        y: 60,
        deltaX: 4,
        deltaY: 5,
        button: 1,
        buttons: 0,
        timestamp: Duration(milliseconds: 20),
      ),
    );

    expect(stage.pointer.x, 44);
    expect(stage.pointer.y, 60);
    expect(stage.pointer.isDown, isFalse);
    expect(stage.pointer.pointer(7)?.down, isFalse);
    expect(types, [GPointerEventType.down, GPointerEventType.up]);
  });

  test('external host boundary ingress preserves enter exit state', () {
    final stage = GStage(GRoot())
      ..mount()
      ..setViewport(320, 240);
    addTearDown(stage.dispose);

    stage.input.dispatchPointerBoundary(
      const GPointerBoundaryEvent(
        type: GPointerBoundaryEventType.enter,
        pointer: 1,
        kind: GPointerDeviceKind.mouse,
        x: 12,
        y: 18,
        timestamp: Duration.zero,
      ),
    );
    expect(stage.pointer.isInside, isTrue);

    stage.input.dispatchPointerBoundary(
      const GPointerBoundaryEvent(
        type: GPointerBoundaryEventType.exit,
        pointer: 1,
        kind: GPointerDeviceKind.mouse,
        x: 14,
        y: 20,
        timestamp: Duration(milliseconds: 1),
      ),
    );
    expect(stage.pointer.isInside, isFalse);
  });

  test('external host pan zoom ingress preserves the shared mutable state', () {
    final stage = GStage(GRoot())
      ..mount()
      ..setViewport(320, 240);
    addTearDown(stage.dispose);

    var updates = 0;
    stage.pointer.onPanZoomUpdate.add((_) => updates++);

    stage.input.beginPointerPanZoom(pointerId: 3, x: 100, y: 90);
    expect(stage.pointer.panZoom.active, isTrue);
    expect(stage.pointer.panZoom.pointer, 3);

    stage.input.updatePointerPanZoom(
      pointerId: 3,
      x: 102,
      y: 93,
      panX: 8,
      panY: -5,
      panDeltaX: 2,
      panDeltaY: -1,
      scale: 1.2,
      rotation: .25,
      timestamp: const Duration(milliseconds: 16),
    );

    expect(updates, 1);
    expect(stage.pointer.panZoom.panX, 8);
    expect(stage.pointer.panZoom.panY, -5);
    expect(stage.pointer.panZoom.scale, 1.2);
    expect(stage.pointer.panZoom.rotation, .25);

    stage.input.endPointerPanZoom();
    expect(stage.pointer.panZoom.active, isFalse);
  });

  test('external host keyboard ingress and reset share raw key state', () {
    final stage = GStage(GRoot())
      ..mount()
      ..setViewport(320, 240);
    addTearDown(stage.dispose);

    final handled = stage.input.dispatchKey(
      GKeyEvent(
        type: GKeyEventType.down,
        logicalKey: LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
        timestamp: Duration.zero,
        character: 'a',
      ),
    );

    expect(handled, isFalse);
    expect(stage.input.keyboard.isDown(GKey.keyA), isTrue);

    stage.input.resetKeyboard();
    expect(stage.input.keyboard.isDown(GKey.keyA), isFalse);
  });
}
