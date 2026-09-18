import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cache is lazy, warmup is idempotent, and root transform stays valid',
    () async {
      final root = GRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(320, 240, devicePixelRatio: 2);
      final group = root.addChild(GNode('cached'));
      final shape = group.addChild(GShape());
      shape.graphics
        ..beginFill(const ui.Color(0xffffffff))
        ..drawRect(0, 0, 40, 30)
        ..endFill();

      group.cache
        ..enabled = true
        ..scale = 2;
      await group.cache.prepare();
      await group.cache.prepare();

      expect(group.cache.isReady, isTrue);
      expect(group.cache.captures, 1);
      expect(group.cache.rasterScale, 2);

      group
        ..x = 80
        ..y = 40
        ..rotation = .35
        ..scaleX = 1.7
        ..scaleY = 1.7;

      expect(group.cache.isDirty, isFalse);
      expect(group.cache.captures, 1);

      group.dispose();
      stage.dispose();
    },
  );

  test('fixed-scale cache can be prepared before Stage attachment', () async {
    final group = GNode('detached-cached');
    group.addChild(GShape()).graphics
      ..beginFill(const ui.Color(0xff59d9d0))
      ..drawRect(0, 0, 40, 30)
      ..endFill();

    group.cache
      ..enabled = true
      ..scale = 2;

    expect(group.isAttached, isFalse);
    await group.cache.prepare();

    expect(group.isAttached, isFalse);
    expect(group.cache.isReady, isTrue);
    expect(group.cache.captures, 1);
    expect(group.cache.rasterScale, 2);
    expect(group.cache.pixelWidth, 80);
    expect(group.cache.pixelHeight, 60);

    final root = GRoot();
    final stage = GStage(root)
      ..mount()
      ..setViewport(320, 240, devicePixelRatio: 3);
    root.addChild(group);

    expect(group.isAttached, isTrue);
    expect(group.cache.isReady, isTrue);
    expect(group.cache.captures, 1);
    expect(group.cache.rasterScale, 2);

    final renderer = GCanvasRenderer();
    final recorder = ui.PictureRecorder();
    renderer.render(ui.Canvas(recorder), stage);
    recorder.endRecording().dispose();
    expect(group.cache.captures, 1);

    renderer.dispose();
    group.dispose();
    stage.dispose();
  });

  test(
    'detached automatic cache starts at 1x and promotes after attachment',
    () async {
      final group = GNode('detached-auto')
        ..scaleX = 1.5
        ..scaleY = 1.5;
      group.addChild(GShape()).graphics
        ..beginFill(const ui.Color(0xffffffff))
        ..drawRect(0, 0, 20, 10)
        ..endFill();

      group.cache.enabled = true;
      await group.cache.prepare();

      expect(group.isAttached, isFalse);
      expect(group.cache.isReady, isTrue);
      expect(group.cache.rasterScale, 1);
      expect(group.cache.captures, 1);

      final root = GRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(320, 240, devicePixelRatio: 2);
      root.addChild(group);

      await group.cache.prepare();

      expect(group.cache.isReady, isTrue);
      expect(group.cache.rasterScale, closeTo(3, 1e-9));
      expect(group.cache.captures, 2);

      group.dispose();
      stage.dispose();
    },
  );

  test(
    'descendant visual and transform mutations invalidate cached ancestor',
    () async {
      final root = GRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(320, 240);
      final group = root.addChild(GNode('cached'));
      final shape = group.addChild(GShape());
      shape.graphics
        ..beginFill(const ui.Color(0xffffffff))
        ..drawRect(0, 0, 40, 30)
        ..endFill();

      group.cache
        ..enabled = true
        ..scale = 1;
      await group.cache.prepare();
      expect(group.cache.captures, 1);

      shape.x = 12;
      expect(group.cache.isDirty, isTrue);
      await group.cache.prepare();
      expect(group.cache.captures, 2);

      shape.graphics
        ..clear()
        ..beginFill(const ui.Color(0xffff0000))
        ..drawRect(0, 0, 40, 30)
        ..endFill();
      expect(group.cache.isDirty, isTrue);
      await group.cache.prepare();
      expect(group.cache.captures, 3);

      group.dispose();
      stage.dispose();
    },
  );

  test(
    'nested caches invalidate independently from one descendant mutation',
    () async {
      final root = GRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(320, 240);
      final outer = root.addChild(GNode('outer'));
      final inner = outer.addChild(GNode('inner'));
      final shape = inner.addChild(GShape());
      shape.graphics
        ..beginFill(const ui.Color(0xff59d9d0))
        ..drawRect(0, 0, 24, 24)
        ..endFill();

      inner.cache
        ..enabled = true
        ..scale = 1;
      outer.cache
        ..enabled = true
        ..scale = 1;
      await inner.cache.prepare();
      await outer.cache.prepare();

      expect(inner.cache.isReady, isTrue);
      expect(outer.cache.isReady, isTrue);

      shape.x = 8;
      expect(inner.cache.isDirty, isTrue);
      expect(outer.cache.isDirty, isTrue);

      await inner.cache.prepare();
      await outer.cache.prepare();
      expect(inner.cache.captures, 2);
      expect(outer.cache.captures, 2);

      outer.dispose();
      stage.dispose();
    },
  );

  test(
    'auto cache scale follows DPR and effective world scale on warmup',
    () async {
      final root = GRoot();
      final stage = GStage(root)
        ..mount()
        ..setViewport(320, 240, devicePixelRatio: 2);
      final group = root.addChild(GNode('cached'))
        ..scaleX = 1.5
        ..scaleY = 1.5;
      group.addChild(GShape()).graphics
        ..beginFill(const ui.Color(0xffffffff))
        ..drawRect(0, 0, 20, 10)
        ..endFill();

      group.cache.enabled = true;
      await group.cache.prepare();

      expect(group.cache.rasterScale, closeTo(3, 1e-9));
      expect(group.cache.pixelWidth, greaterThan(0));
      expect(group.cache.pixelHeight, greaterThan(0));

      group.dispose();
      stage.dispose();
    },
  );

  test('filter effect bounds are included in retained raster extent', () async {
    final root = GRoot();
    final stage = GStage(root)
      ..mount()
      ..setViewport(320, 240);
    final group = root.addChild(GNode('filtered'));
    group.addChild(GShape()).graphics
      ..beginFill(const ui.Color(0xffffffff))
      ..drawRect(0, 0, 40, 30)
      ..endFill();
    group.filters = [GBlurFilter(blurX: 6, blurY: 6)];
    group.cache
      ..enabled = true
      ..scale = 1;

    await group.cache.prepare();

    expect(group.cache.pixelWidth, greaterThan(40));
    expect(group.cache.pixelHeight, greaterThan(30));

    group.dispose();
    stage.dispose();
  });

  for (final blend in const <ui.BlendMode>[
    ui.BlendMode.multiply,
    ui.BlendMode.screen,
    ui.BlendMode.overlay,
  ]) {
    test(
      'cached $blend preserves root blend against parent destination',
      () async {
        final root = GRoot();
        final stage = GStage(root)
          ..mount()
          ..setViewport(64, 64);

        root.addChild(GShape()).graphics
          ..beginFill(const ui.Color(0xff416ea0))
          ..drawRect(0, 0, 64, 64)
          ..endFill();

        final target = root.addChild(GNode('blend'))..blendMode = blend;
        target.addChild(GShape()).graphics
          ..beginFill(const ui.Color(0xffd65a78))
          ..drawRect(8, 8, 48, 48)
          ..endFill();

        final renderer = GCanvasRenderer();
        final live = await _renderPixels(renderer, stage, 64, 64);

        target.cache
          ..enabled = true
          ..scale = 1;
        await target.cache.prepare();
        final cached = await _renderPixels(renderer, stage, 64, 64);

        _expectPixelClose(live, cached, 32, 32, 64, tolerance: 1);
        _expectPixelClose(live, cached, 4, 4, 64, tolerance: 0);

        renderer.dispose();
        target.dispose();
        stage.dispose();
      },
    );
  }
}

Future<Uint8List> _renderPixels(
  GCanvasRenderer renderer,
  GStage stage,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  renderer.render(ui.Canvas(recorder), stage);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void _expectPixelClose(
  Uint8List a,
  Uint8List b,
  int x,
  int y,
  int width, {
  required int tolerance,
}) {
  final offset = (y * width + x) * 4;
  for (var channel = 0; channel < 4; ++channel) {
    expect(
      (a[offset + channel] - b[offset + channel]).abs(),
      lessThanOrEqualTo(tolerance),
      reason: 'pixel ($x,$y), channel $channel',
    );
  }
}
