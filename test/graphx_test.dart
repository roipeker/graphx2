import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('GStage mounts a root', () {
    final root = GRoot();
    final stage = GStage(root);
    stage.mount();
    expect(stage.isMounted, isTrue);
    stage.dispose();
    expect(stage.isDisposed, isTrue);
  });
}
