import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets(
    'GraphxView dispatches inherited dependencies once per dependency change',
    (tester) async {
      final controller = GraphxController<_DependencyRoot>();
      const viewKey = ValueKey<String>('graphx');

      Widget host({
        required int marker,
        required int noise,
        required String value,
      }) => Directionality(
        textDirection: TextDirection.ltr,
        child: _Marker(
          value: marker,
          child: _NoiseHost(
            noise: noise,
            child: SizedBox(
              width: 160,
              height: 100,
              child: GraphxView(
                key: viewKey,
                root: _DependencyRoot.new,
                controller: controller,
                value: value,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(host(marker: 1, noise: 0, value: 'first'));
      await tester.pump();

      final root = controller.root;
      expect(root.dependencyCalls, 1);
      expect(root.syncCalls, 1);
      expect(root.marker, 1);
      expect(root.value, 'first');

      await tester.pumpWidget(host(marker: 1, noise: 1, value: 'second'));
      await tester.pump();

      expect(identical(root, controller.root), isTrue);
      expect(root.dependencyCalls, 1);
      expect(root.syncCalls, 2);
      expect(root.marker, 1);
      expect(root.value, 'second');

      await tester.pumpWidget(host(marker: 2, noise: 1, value: 'second'));
      await tester.pump();

      expect(root.dependencyCalls, 2);
      expect(root.syncCalls, 3);
      expect(root.marker, 2);
      expect(root.value, 'second');
    },
  );

  testWidgets(
    'GraphxView.scene can subscribe to inherited dependencies without rebuilding',
    (tester) async {
      const viewKey = ValueKey<String>('scene');
      var builderCalls = 0;
      var dependencyCalls = 0;
      var syncCalls = 0;
      var marker = 0;
      Object? value;

      Widget host(int nextMarker, String nextValue) => Directionality(
        textDirection: TextDirection.ltr,
        child: _Marker(
          value: nextMarker,
          child: SizedBox(
            width: 160,
            height: 100,
            child: GraphxView.scene(key: viewKey, (root) {
              builderCalls++;
              root.stage.signals.onFlutterDependencies.add((context) {
                dependencyCalls++;
                marker = _Marker.of(context).value;
              });
              root.stage.signals.onFlutterSync.add((sync) {
                syncCalls++;
                value = sync.value;
              });
            }, value: nextValue),
          ),
        ),
      );

      await tester.pumpWidget(host(7, 'first'));
      await tester.pump();

      expect(builderCalls, 1);
      expect(dependencyCalls, 1);
      expect(syncCalls, 1);
      expect(marker, 7);
      expect(value, 'first');

      await tester.pumpWidget(host(9, 'second'));
      await tester.pump();

      expect(builderCalls, 1);
      expect(dependencyCalls, 2);
      expect(syncCalls, 2);
      expect(marker, 9);
      expect(value, 'second');
    },
  );
}

final class _DependencyRoot extends GRoot {
  int dependencyCalls = 0;
  int syncCalls = 0;
  int? marker;
  Object? value;

  @override
  void attached() {
    stage.signals.onFlutterDependencies.add((context) {
      dependencyCalls++;
      marker = _Marker.of(context).value;
    });
    stage.signals.onFlutterSync.add((sync) {
      syncCalls++;
      value = sync.value;
    });
  }
}

final class _NoiseHost extends StatelessWidget {
  const _NoiseHost({required this.noise, required this.child});

  final int noise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(noise >= 0);
    return child;
  }
}

final class _Marker extends InheritedWidget {
  const _Marker({required this.value, required super.child});

  final int value;

  static _Marker of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Marker>()!;

  @override
  bool updateShouldNotify(_Marker oldWidget) => value != oldWidget.value;
}
