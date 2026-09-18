import 'package:flutter/material.dart';
import 'package:graphx/graphx.dart';

void main() => runApp(const MaterialApp(home: _GraphxExample()));

class _GraphxExample extends StatelessWidget {
  const _GraphxExample();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GraphxView.scene((root) {
        final shape = root.addChild(GShape('card'));
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
