import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets('content hit testing falls through an empty GraphX scene', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
              GraphxView.scene(
                (_) {},
                config: const GraphxConfig(
                  hitTestBehavior: GHitTestBehavior.content,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('opaque hit testing keeps the full GraphX surface interactive', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
              GraphxView.scene(
                (_) {},
                config: const GraphxConfig(
                  hitTestBehavior: GHitTestBehavior.opaque,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(taps, 0);
  });
}
