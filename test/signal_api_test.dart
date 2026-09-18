// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('engine-owned signals keep the mutable signal API', () {
    final node = GNode();
    var focused = false;

    node.onFocusChanged.add((value) => focused = value);
    node.onFocusChanged.emit(true);

    expect(focused, isTrue);
  });
}
