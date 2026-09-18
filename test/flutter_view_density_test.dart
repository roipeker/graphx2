import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets('GraphXView tracks the owning FlutterView density', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 2.0;

    final controller = GraphXController<GRoot>();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 240,
            child: GraphXView(root: GRoot.new, controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    final stage = controller.root.stage;
    expect(stage.devicePixelRatio, 2.0);

    tester.view.devicePixelRatio = 1.25;
    await tester.pump();

    expect(controller.root.stage, same(stage));
    expect(stage.devicePixelRatio, 1.25);
    expect(stage.width, 320);
    expect(stage.height, 240);
  });
}
