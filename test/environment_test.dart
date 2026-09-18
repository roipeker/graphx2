import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first environment read sees current inherited values', (
    tester,
  ) async {
    final root = _EnvironmentRoot();
    const key = ValueKey('graphx');

    Widget host(Brightness brightness, TextScaler scaler) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(240, 120),
          platformBrightness: brightness,
          textScaler: scaler,
        ),
        child: SizedBox(
          width: 240,
          height: 120,
          child: GraphxView(key: key, root: () => root),
        ),
      ),
    );

    await tester.pumpWidget(
      host(Brightness.dark, const TextScaler.linear(1.6)),
    );

    expect(root.initialBrightness, Brightness.dark);
    expect(root.initialScaled10, 16);
    expect(root.environmentChanges, 0);

    await tester.pumpWidget(
      host(Brightness.light, const TextScaler.linear(1.2)),
    );

    expect(root.environmentChanges, 1);
    expect(root.lastChange?.brightness, isTrue);
    expect(root.lastChange?.textScaler, isTrue);
    expect(root.currentBrightness, Brightness.light);
    expect(root.currentScaled10, 12);
  });
}

final class _EnvironmentRoot extends GRoot {
  late Brightness initialBrightness;
  late double initialScaled10;
  Brightness? currentBrightness;
  double? currentScaled10;
  int environmentChanges = 0;
  GEnvironmentChange? lastChange;

  @override
  void attached() {
    initialBrightness = stage.environment.brightness;
    initialScaled10 = stage.environment.textScaler.scale(10);
  }

  @override
  void environmentChanged(GEnvironmentChange change) {
    environmentChanges++;
    lastChange = change;
    currentBrightness = stage.environment.brightness;
    currentScaled10 = stage.environment.textScaler.scale(10);
  }
}
