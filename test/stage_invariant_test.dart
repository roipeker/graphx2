import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  group('GStage invariants', () {
    test(
      'hosted structural mutation during render is rejected and recovers',
      () {
        final root = GRoot();
        final node = root.addChild(_RenderAddingNode());
        final stage = GStage(root)
          ..mount()
          ..setViewport(32, 32);
        final recorder = PictureRecorder();
        final renderer = GCanvasRenderer();

        expect(
          () => renderer.render(Canvas(recorder), stage),
          throwsStateError,
        );
        expect(node.numChildren, 0);

        node.mutate = false;
        expect(() => node.addChild(GNode()), returnsNormally);
        expect(node.numChildren, 1);

        renderer.dispose();
        recorder.endRecording().dispose();
        stage.dispose();
      },
    );

    test('node disposal during render is rejected before state changes', () {
      final root = GRoot();
      final node = root.addChild(_RenderDisposingNode());
      final stage = GStage(root)
        ..mount()
        ..setViewport(32, 32);
      final recorder = PictureRecorder();
      final renderer = GCanvasRenderer();

      expect(() => renderer.render(Canvas(recorder), stage), throwsStateError);
      expect(node.isDisposed, isFalse);
      expect(node.isAttached, isTrue);
      expect(node.parent, same(root));

      node.disposeOnPaint = false;
      node.dispose();
      expect(node.isDisposed, isTrue);
      expect(root.numChildren, 0);

      renderer.dispose();
      recorder.endRecording().dispose();
      stage.dispose();
    });

    test('Stage disposal during render is rejected before state changes', () {
      final root = GRoot();
      root.addChild(_RenderStageDisposingNode());
      final stage = GStage(root)
        ..mount()
        ..setViewport(32, 32);
      final recorder = PictureRecorder();
      final renderer = GCanvasRenderer();

      expect(() => renderer.render(Canvas(recorder), stage), throwsStateError);
      expect(stage.isDisposed, isFalse);
      expect(stage.isMounted, isTrue);
      expect(root.isAttached, isTrue);

      renderer.dispose();
      recorder.endRecording().dispose();
      stage.dispose();
      expect(root.isAttached, isFalse);
    });

    test(
      'viewport lifecycle mutation during render is rejected atomically',
      () {
        final root = GRoot();
        root.addChild(_RenderViewportChangingNode());
        final stage = GStage(root)
          ..mount()
          ..setViewport(32, 32);
        final recorder = PictureRecorder();
        final renderer = GCanvasRenderer();

        expect(
          () => renderer.render(Canvas(recorder), stage),
          throwsStateError,
        );
        expect(stage.width, 32);
        expect(stage.height, 32);

        stage.setViewport(64, 48);
        expect(stage.width, 64);
        expect(stage.height, 48);

        renderer.dispose();
        recorder.endRecording().dispose();
        stage.dispose();
      },
    );

    test('recursive update is rejected and tick state recovers', () {
      final root = GRoot();
      root.addChild(_RecursiveUpdater());
      final stage = GStage(root)
        ..mount()
        ..setViewport(32, 32);

      expect(() => stage.tick(1 / 60), throwsStateError);
      expect(() => stage.tick(1 / 60), returnsNormally);

      stage.dispose();
    });

    test(
      'Stage disposal during update is rejected and update state recovers',
      () {
        final root = GRoot();
        root.addChild(_UpdateStageDisposer());
        final stage = GStage(root)
          ..mount()
          ..setViewport(32, 32);

        expect(() => stage.tick(1 / 60), throwsStateError);
        expect(stage.isDisposed, isFalse);
        expect(stage.isMounted, isTrue);
        expect(root.isAttached, isTrue);
        expect(() => stage.tick(1 / 60), returnsNormally);

        stage.dispose();
      },
    );

    test('structural mutation remains legal during update', () {
      final root = GRoot();
      final node = root.addChild(_UpdateAddingNode());
      final stage = GStage(root)
        ..mount()
        ..setViewport(32, 32);

      stage.tick(1 / 60);

      expect(node.numChildren, 1);
      expect(node.getChildAt(0).parent, same(node));

      stage.dispose();
    });

    test('tick requires root lifecycle attachment', () {
      final root = GRoot();
      final stage = GStage(root)..mount();

      expect(() => stage.tick(1 / 60), throwsStateError);
      expect(stage.frame, 0);
      expect(stage.elapsed, 0);

      stage.setViewport(32, 32);
      expect(() => stage.tick(1 / 60), returnsNormally);
      expect(stage.frame, 1);

      stage.dispose();
    });

    test('disposed root cannot leave Stage half-mounted', () {
      final root = GRoot()..dispose();
      final stage = GStage(root);

      expect(stage.mount, throwsStateError);
      expect(stage.isMounted, isFalse);

      stage.dispose();
    });

    test('root owned by another Stage cannot half-mount or be stolen', () {
      final root = GRoot();
      final first = GStage(root)..mount();
      final second = GStage(root);

      expect(second.mount, throwsStateError);
      expect(second.isMounted, isFalse);
      expect(root.isDisposed, isFalse);

      second.dispose();
      expect(root.isDisposed, isFalse);

      first.dispose();
      expect(root.isDisposed, isTrue);
    });

    test('Stage dispose signal emits exactly once', () {
      final stage = GStage(GRoot())
        ..mount()
        ..setViewport(32, 32);
      var calls = 0;
      stage.signals.onDispose.add(() => calls++);

      stage.dispose();
      stage.dispose();

      expect(calls, 1);
    });
  });
}

final class _RenderAddingNode extends GNode {
  _RenderAddingNode() {
    setPaintSelf(true);
  }

  bool mutate = true;

  @override
  void paintSelf(GRenderContext context) {
    if (mutate) addChild(GNode());
  }
}

final class _RenderDisposingNode extends GNode {
  _RenderDisposingNode() {
    setPaintSelf(true);
  }

  bool disposeOnPaint = true;

  @override
  void paintSelf(GRenderContext context) {
    if (disposeOnPaint) dispose();
  }
}

final class _RenderStageDisposingNode extends GNode {
  _RenderStageDisposingNode() {
    setPaintSelf(true);
  }

  @override
  void paintSelf(GRenderContext context) {
    stage.dispose();
  }
}

final class _RenderViewportChangingNode extends GNode {
  _RenderViewportChangingNode() {
    setPaintSelf(true);
  }

  @override
  void paintSelf(GRenderContext context) {
    stage.setViewport(64, 48);
  }
}

final class _RecursiveUpdater extends GNode {
  _RecursiveUpdater() {
    updatesEnabled = true;
  }

  bool recurse = true;

  @override
  void update(double delta) {
    if (!recurse) return;
    recurse = false;
    stage.tick(delta);
  }
}

final class _UpdateStageDisposer extends GNode {
  _UpdateStageDisposer() {
    updatesEnabled = true;
  }

  bool disposeOnce = true;

  @override
  void update(double delta) {
    if (!disposeOnce) return;
    disposeOnce = false;
    stage.dispose();
  }
}

final class _UpdateAddingNode extends GNode {
  _UpdateAddingNode() {
    updatesEnabled = true;
  }

  bool addOnce = true;

  @override
  void update(double delta) {
    if (!addOnce) return;
    addOnce = false;
    addChild(GNode());
  }
}
