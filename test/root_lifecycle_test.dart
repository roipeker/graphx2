// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test(
    'root attaches then resizes on first usable viewport and real changes only',
    () {
      final root = _LifecycleRoot();
      final stage = GStage(root)..mount();

      expect(root.attachedCount, 0);
      expect(root.resizeCount, 0);
      expect(root.isAttached, isFalse);

      stage.setViewport(0, 100);
      expect(root.attachedCount, 0);
      expect(root.resizeCount, 0);

      stage.setViewport(320, 240);
      expect(root.lifecycle, ['attached', 'resize']);
      expect(root.attachedCount, 1);
      expect(root.resizeCount, 1);
      expect(root.lastResizeWidth, 320);
      expect(root.lastResizeHeight, 240);

      stage.setViewport(320, 240);
      expect(root.resizeCount, 1);

      stage.setViewport(640, 480);
      expect(root.attachedCount, 1);
      expect(root.resizeCount, 2);
      expect(root.lastResizeWidth, 640);
      expect(root.lastResizeHeight, 480);

      stage.setViewport(640, 480, devicePixelRatio: 2);
      expect(root.resizeCount, 3);
      expect(root.lastResizeWidth, 640);
      expect(root.lastResizeHeight, 480);
      expect(root.lastDevicePixelRatio, 2);

      stage.dispose();
    },
  );

  test(
    'children added before the first usable viewport attach with the root',
    () {
      final root = GRoot();
      final stage = GStage(root)..mount();
      final child = root.addChild(_ChildLifecycleNode());

      expect(root.isAttached, isFalse);
      expect(child.isAttached, isFalse);
      expect(child.attachedCount, 0);

      stage.setViewport(320, 240);

      expect(root.isAttached, isTrue);
      expect(child.isAttached, isTrue);
      expect(child.stage, same(stage));
      expect(child.attachedCount, 1);

      stage.dispose();

      expect(child.detachedCount, 1);
      expect(child.isAttached, isFalse);
      expect(child.isDisposed, isTrue);
    },
  );

  test('root updater configured before mount starts only after attachment', () {
    final root = _UpdatingRoot();
    final stage = GStage(root)..mount();

    expect(() => stage.tick(1 / 60), throwsStateError);
    expect(root.updates, 0);

    stage.setViewport(320, 240);
    stage.tick(1 / 60);

    expect(root.updates, 1);
    stage.dispose();
  });

  test('Stage owns its mounted root until Stage disposal', () {
    final root = GRoot();
    final stage = GStage(root)
      ..mount()
      ..setViewport(320, 240);

    expect(root.dispose, throwsStateError);
    expect(root.isDisposed, isFalse);
    expect(root.isAttached, isTrue);

    stage.dispose();

    expect(stage.isMounted, isFalse);
    expect(root.isDisposed, isTrue);
    expect(root.isAttached, isFalse);
    expect(() => root.stage, throwsStateError);
  });

  test('Stage disposal detaches root lifecycle exactly once', () {
    final root = _LifecycleRoot();
    final stage = GStage(root)
      ..mount()
      ..setViewport(320, 240);

    stage.dispose();
    stage.dispose();

    expect(root.attachedCount, 1);
    expect(root.detachedCount, 1);
    expect(root.isAttached, isFalse);
  });

  testWidgets(
    'GraphXView syncs inherited widgets and value after root attachment',
    (tester) async {
      final controller = GraphXController<_LifecycleRoot>();

      Widget build(int marker, String value) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: _Marker(
            value: marker,
            child: SizedBox(
              width: 320,
              height: 240,
              child: GraphXView(
                root: _LifecycleRoot.new,
                controller: controller,
                value: value,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(7, 'first'));
      await tester.pump();

      final root = controller.root;
      expect(root.attachedCount, 1);
      expect(root.resizeCount, 1);
      expect(root.attachedWidth, 320);
      expect(root.attachedHeight, 240);
      expect(root.markerValue, 7);
      expect(root.flutterValue, 'first');

      await tester.pumpWidget(build(9, 'second'));
      await tester.pump();

      expect(identical(root, controller.root), isTrue);
      expect(root.attachedCount, 1);
      expect(root.markerValue, 9);
      expect(root.flutterValue, 'second');
    },
  );

  testWidgets('GraphXView.scene starts with a usable viewport', (tester) async {
    var calls = 0;
    var width = 0.0;
    var height = 0.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 280,
            height: 180,
            child: GraphXView.scene((root) {
              calls++;
              width = root.stage.width;
              height = root.stage.height;
              root.addChild(GNode());
            }),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(calls, 1);
    expect(width, 280);
    expect(height, 180);
  });
}

final class _LifecycleRoot extends GRoot {
  int attachedCount = 0;
  int detachedCount = 0;
  int resizeCount = 0;
  double attachedWidth = 0;
  double attachedHeight = 0;
  double lastResizeWidth = 0;
  double lastResizeHeight = 0;
  double lastDevicePixelRatio = 1;
  int? markerValue;
  Object? flutterValue;
  final lifecycle = <String>[];

  @override
  void attached() {
    lifecycle.add('attached');
    attachedCount++;
    attachedWidth = stage.width;
    attachedHeight = stage.height;

    stage.signals.onFlutterDependencies.add((context) {
      markerValue = context.dependOnInheritedWidgetOfExactType<_Marker>()?.value;
    });
    stage.signals.onFlutterSync.add((sync) {
      flutterValue = sync.value;
    });
  }

  @override
  void detached() {
    detachedCount++;
  }

  @override
  void resize(double w, double h) {
    lifecycle.add('resize');
    resizeCount++;
    lastResizeWidth = w;
    lastResizeHeight = h;
    lastDevicePixelRatio = stage.devicePixelRatio;
  }
}

final class _UpdatingRoot extends GRoot {
  _UpdatingRoot() {
    updatesEnabled = true;
  }

  int updates = 0;

  @override
  void update(double delta) {
    updates++;
  }
}

final class _ChildLifecycleNode extends GNode {
  int attachedCount = 0;
  int detachedCount = 0;

  @override
  void attached() {
    attachedCount++;
  }

  @override
  void detached() {
    detachedCount++;
  }
}

final class _Marker extends InheritedWidget {
  const _Marker({required this.value, required super.child});

  final int value;

  @override
  bool updateShouldNotify(_Marker oldWidget) => value != oldWidget.value;
}
