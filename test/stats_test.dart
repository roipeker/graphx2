import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('frame stats track deterministic host cadence only when enabled', () {
    final stage = GStage(GRoot());
    stage.mount();
    stage.setViewport(100, 100);

    final stats = stage.stats;
    expect(stats.enabled, isFalse);
    stage.tick(1 / 60);

    stats.enabled = true;
    stage.tick(1 / 60);
    stage.tick(1 / 60);

    final frame = stats.frame;
    expect(frame.frames, 2);
    expect(frame.fps, closeTo(60, .01));
    expect(frame.frameMilliseconds, closeTo(1000 / 60, .01));
    expect(frame.lastFrameMilliseconds, closeTo(1000 / 60, .01));
    expect(frame.maxFrameMilliseconds, closeTo(1000 / 60, .01));
    expect(frame.update.count, 2);

    stats.reset();
    expect(frame.frames, 0);
    expect(frame.fps, 0);
    expect(frame.update.count, 0);

    stage.dispose();
  });

  test(
    'frame cadence uses frames over elapsed time instead of averaging fps',
    () {
      final stage = GStage(GRoot());
      stage.mount();
      stage.setViewport(100, 100);
      stage.stats.enabled = true;

      stage.tick(1 / 120);
      stage.tick(1 / 60);
      stage.tick(1 / 30);

      final frame = stage.stats.frame;
      final seconds = 1 / 120 + 1 / 60 + 1 / 30;
      expect(frame.fps, closeTo(3 / seconds, .001));
      expect(frame.frameMilliseconds, closeTo(seconds * 1000 / 3, .001));
      expect(frame.lastFrameMilliseconds, closeTo(1000 / 30, .001));
      expect(frame.maxFrameMilliseconds, closeTo(1000 / 30, .001));
      expect(frame.update.count, 3);

      stage.dispose();
    },
  );

  test('continuous update state excludes one-shot requested work', () {
    final root = GRoot();
    final stage = GStage(root);
    stage.mount();
    stage.setViewport(100, 100);

    expect(stage.hasContinuousUpdates, isFalse);
    expect(stage.wantsUpdate, isFalse);

    stage.requestUpdate();
    expect(stage.wantsUpdate, isTrue);
    expect(stage.hasContinuousUpdates, isFalse);

    stage.tick(0);
    expect(stage.wantsUpdate, isFalse);

    root.updatesEnabled = true;
    expect(stage.hasContinuousUpdates, isTrue);
    expect(stage.wantsUpdate, isTrue);

    root.updatesEnabled = false;
    expect(stage.hasContinuousUpdates, isFalse);
    expect(stage.wantsUpdate, isFalse);

    stage.dispose();
  });

  test('scene node count is live without enabling instrumentation', () {
    final root = GRoot();
    final stage = GStage(root);
    stage.mount();
    final scene = stage.stats.scene;

    expect(stage.stats.enabled, isFalse);
    expect(scene.nodeCount, 1);

    stage.setViewport(100, 100);
    final parent = root.addChild(GNode(name: 'parent'));
    final child = parent.addChild(GNode(name: 'child'));
    expect(scene.nodeCount, 3);

    parent.removeChild(child);
    expect(scene.nodeCount, 2);

    root.removeChild(parent);
    expect(scene.nodeCount, 1);

    stage.dispose();
    expect(scene.nodeCount, 0);
  });
}
