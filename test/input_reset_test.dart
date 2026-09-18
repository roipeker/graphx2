// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('disabling Stage input emits lazy pointer and keyboard resets', () {
    final stage = GStage(GRoot())..mount();
    var pointerResets = 0;
    var keyboardResets = 0;
    final pointerSubscription = stage.input.pointer.onReset.add((manager) {
      pointerResets++;
      expect(manager, same(stage.input.pointer));
      expect(manager.isDown, isFalse);
      expect(manager.pointerCount, 0);
    });
    final keyboardSubscription = stage.input.keyboard.onReset.add((manager) {
      keyboardResets++;
      expect(manager, same(stage.input.keyboard));
      expect(manager.downKeys, isEmpty);
    });

    stage.input.enabled = false;
    expect(pointerResets, 1);
    expect(keyboardResets, 1);

    // Idempotent setter must not manufacture lifecycle transitions.
    stage.input.enabled = false;
    expect(pointerResets, 1);
    expect(keyboardResets, 1);

    stage.input.enabled = true;
    stage.input.enabled = false;
    expect(pointerResets, 2);
    expect(keyboardResets, 2);

    pointerSubscription.cancel();
    keyboardSubscription.cancel();
    stage.dispose();
  });
}
