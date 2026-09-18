// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter/material.dart';
import 'package:graphx/graphx.dart';

void main() => runApp(const MaterialApp(home: _GraphXExample()));

class _GraphXExample extends StatelessWidget {
  const _GraphXExample();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GraphXView.scene((root) {
        final shape = root.addChild(GShape(name: 'card'));
        shape.graphics
          ..beginFill(const Color(0xff6750a4))
          ..drawRoundRect(-90, -40, 180, 80, 20)
          ..endFill();
        shape
          ..x = 180
          ..y = 160;
      }),
    );
  }
}
