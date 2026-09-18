// Copyright (c) 2026 GraphX by roipeker.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';
import 'package:graphx/graphx_extension.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('image batch grows and keeps ergonomic instance state', () async {
    final image = await _image(8, 6);
    final texture = GTexture(image);
    final batch = GImageBatch(capacity: 1);

    final a = batch.add(texture, x: 10, y: 20);
    final b = batch.add(texture, x: 30, y: 40, scale: 2);

    expect(batch.length, 2);
    expect(batch.capacity, greaterThanOrEqualTo(2));
    expect(batch[0], same(a));
    expect(batch[1], same(b));

    a
      ..x = 12
      ..y = 24
      ..rotation = .25
      ..scale = .5;
    expect(a.x, 12);
    expect(a.y, 24);
    expect(a.rotation, .25);
    expect(a.scale, .5);

    batch.dispose();
    texture.dispose();
    image.dispose();
  });

  test(
    'middle removal preserves order and updates surviving handles',
    () async {
      final image = await _image(4, 4);
      final texture = GTexture(image);
      final batch = GImageBatch(capacity: 3);

      final a = batch.add(texture, x: 1);
      final b = batch.add(texture, x: 2);
      final c = batch.add(texture, x: 3);

      b.remove();

      expect(batch.length, 2);
      expect(batch[0], same(a));
      expect(batch[1], same(c));
      expect(b.isAttached, isFalse);
      expect(c.isAttached, isTrue);

      c.x = 9;
      expect(batch[1].x, 9);
      expect(() => b.x = 4, throwsStateError);

      batch.dispose();
      texture.dispose();
      image.dispose();
    },
  );

  test('clear and dispose detach lightweight instances', () async {
    final image = await _image(4, 4);
    final texture = GTexture(image);
    final batch = GImageBatch();
    final a = batch.add(texture);
    final b = batch.add(texture);

    batch.clear();
    expect(batch.isEmpty, isTrue);
    expect(a.isAttached, isFalse);
    expect(b.isAttached, isFalse);

    final c = batch.add(texture);
    batch.dispose();
    expect(c.isAttached, isFalse);

    texture.dispose();
    image.dispose();
  });

  test('bounds follow instance position rotation and scale', () async {
    final image = await _image(10, 4);
    final texture = GTexture(image);
    final batch = GImageBatch();
    final instance = batch.add(texture, x: 5, y: 7);

    var bounds = batch.localBounds;
    expect(bounds.x1, closeTo(5, 1e-9));
    expect(bounds.y1, closeTo(7, 1e-9));
    expect(bounds.x2, closeTo(15, 1e-9));
    expect(bounds.y2, closeTo(11, 1e-9));

    instance.setTransform(x: 5, y: 7, rotation: GMath.halfPi, scale: 2);
    bounds = batch.localBounds;
    expect(bounds.x1, closeTo(-3, 1e-8));
    expect(bounds.y1, closeTo(7, 1e-8));
    expect(bounds.x2, closeTo(5, 1e-8));
    expect(bounds.y2, closeTo(27, 1e-8));

    batch.dispose();
    texture.dispose();
    image.dispose();
  });

  test('batch accepts multiple textures and renders ordered runs', () async {
    final imageA = await _image(4, 4, const ui.Color(0xffff0000));
    final imageB = await _image(4, 4, const ui.Color(0xff00ff00));
    final a = GTexture(imageA);
    final b = GTexture(imageB);
    final batch = GImageBatch()
      ..add(a, x: 0)
      ..add(b, x: 4)
      ..add(a, x: 8);
    final root = GRoot()..addChild(batch);
    final stage = GStage(root)
      ..mount()
      ..setViewport(16, 8);
    final renderer = GCanvasRenderer();
    final recorder = ui.PictureRecorder();

    renderer.render(ui.Canvas(recorder), stage);
    final picture = recorder.endRecording();
    final output = await picture.toImage(16, 8);

    expect(output.width, 16);
    expect(output.height, 8);

    output.dispose();
    picture.dispose();
    renderer.dispose();
    stage.dispose();
    a.dispose();
    b.dispose();
    imageA.dispose();
    imageB.dispose();
  });

  test(
    'growth preserves transforms and atlas rects across repeated reuse',
    () async {
      final image = await _atlasImage();
      final atlas = GTexture(image);
      final red = atlas.region(region: GRect(0, 0, 2, 2));
      final green = atlas.region(region: GRect(2, 0, 2, 2));
      final batch = GImageBatch(capacity: 1);
      final first = batch.add(red, x: 0);
      batch.add(green, x: 2);
      batch.add(red, x: 4);
      batch.add(green, x: 6);
      final last = batch.add(red, x: 8);

      expect(batch.capacity, 8);
      first.setTransform(x: 0, y: 0, rotation: 0, scale: 1);
      last.x = 8;

      final root = GRoot()..addChild(batch);
      final stage = GStage(root)
        ..mount()
        ..setViewport(10, 2);
      final renderer = GCanvasRenderer();

      var rgba = await _renderRgba(renderer, stage, 10, 2);
      _expectRgba(rgba, 10, 0, 1, <int>[255, 0, 0, 255]);
      _expectRgba(rgba, 10, 2, 1, <int>[0, 255, 0, 255]);
      _expectRgba(rgba, 10, 4, 1, <int>[255, 0, 0, 255]);
      _expectRgba(rgba, 10, 6, 1, <int>[0, 255, 0, 255]);
      _expectRgba(rgba, 10, 8, 1, <int>[255, 0, 0, 255]);

      batch.clear();
      expect(batch.capacity, 8);
      batch
        ..add(green, x: 0)
        ..add(red, x: 2);

      rgba = await _renderRgba(renderer, stage, 10, 2);
      _expectRgba(rgba, 10, 0, 1, <int>[0, 255, 0, 255]);
      _expectRgba(rgba, 10, 2, 1, <int>[255, 0, 0, 255]);
      _expectRgba(rgba, 10, 4, 1, <int>[0, 0, 0, 0]);

      renderer.dispose();
      stage.dispose();
      red.dispose();
      green.dispose();
      atlas.dispose();
      image.dispose();
    },
  );

  test('texture changes rebuild ordered atlas runs after growth', () async {
    final imageA = await _image(2, 2, const ui.Color(0xffff0000));
    final imageB = await _image(2, 2, const ui.Color(0xff00ff00));
    final red = GTexture(imageA);
    final green = GTexture(imageB);
    final batch = GImageBatch(capacity: 1);
    final first = batch.add(red, x: 0);
    final middle = batch.add(green, x: 2);
    batch.add(red, x: 4);
    final root = GRoot()..addChild(batch);
    final stage = GStage(root)
      ..mount()
      ..setViewport(6, 2);
    final renderer = GCanvasRenderer();

    var rgba = await _renderRgba(renderer, stage, 6, 2);
    _expectRgba(rgba, 6, 0, 1, <int>[255, 0, 0, 255]);
    _expectRgba(rgba, 6, 2, 1, <int>[0, 255, 0, 255]);
    _expectRgba(rgba, 6, 4, 1, <int>[255, 0, 0, 255]);

    middle.texture = red;
    rgba = await _renderRgba(renderer, stage, 6, 2);
    _expectRgba(rgba, 6, 0, 1, <int>[255, 0, 0, 255]);
    _expectRgba(rgba, 6, 2, 1, <int>[255, 0, 0, 255]);
    _expectRgba(rgba, 6, 4, 1, <int>[255, 0, 0, 255]);

    first.texture = green;
    rgba = await _renderRgba(renderer, stage, 6, 2);
    _expectRgba(rgba, 6, 0, 1, <int>[0, 255, 0, 255]);
    _expectRgba(rgba, 6, 2, 1, <int>[255, 0, 0, 255]);
    _expectRgba(rgba, 6, 4, 1, <int>[255, 0, 0, 255]);

    renderer.dispose();
    stage.dispose();
    red.dispose();
    green.dispose();
    imageA.dispose();
    imageB.dispose();
  });

  test(
    'colors stay aligned through growth compaction and clear reuse',
    () async {
      final image = await _image(2, 2);
      final texture = GTexture(image);
      final batch = GImageBatch(capacity: 1);
      final red = batch.add(texture, x: 0, color: const ui.Color(0xffff0000));
      final green = batch.add(texture, x: 2, color: const ui.Color(0xff00ff00));
      final blue = batch.add(texture, x: 4, color: const ui.Color(0xff0000ff));
      final root = GRoot()..addChild(batch);
      final stage = GStage(root)
        ..mount()
        ..setViewport(6, 2);
      final renderer = GCanvasRenderer();

      var rgba = await _renderRgba(renderer, stage, 6, 2);
      _expectRgba(rgba, 6, 0, 1, <int>[255, 0, 0, 255]);
      _expectRgba(rgba, 6, 2, 1, <int>[0, 255, 0, 255]);
      _expectRgba(rgba, 6, 4, 1, <int>[0, 0, 255, 255]);

      green.remove();
      expect(batch[0], same(red));
      expect(batch[1], same(blue));
      rgba = await _renderRgba(renderer, stage, 6, 2);
      _expectRgba(rgba, 6, 0, 1, <int>[255, 0, 0, 255]);
      _expectRgba(rgba, 6, 2, 1, <int>[0, 0, 0, 0]);
      _expectRgba(rgba, 6, 4, 1, <int>[0, 0, 255, 255]);

      batch.clear();
      batch
        ..add(texture, x: 0)
        ..add(texture, x: 2, color: const ui.Color(0xffffff00));
      rgba = await _renderRgba(renderer, stage, 6, 2);
      _expectRgba(rgba, 6, 0, 1, <int>[255, 255, 255, 255]);
      _expectRgba(rgba, 6, 2, 1, <int>[255, 255, 0, 255]);
      _expectRgba(rgba, 6, 4, 1, <int>[0, 0, 0, 0]);

      renderer.dispose();
      stage.dispose();
      texture.dispose();
      image.dispose();
    },
  );

  test('disposed textures are rejected', () async {
    final image = await _image(2, 2);
    final texture = GTexture(image)..dispose();
    final batch = GImageBatch();

    expect(() => batch.add(texture), throwsStateError);

    batch.dispose();
    image.dispose();
  });
}

Future<Uint8List> _renderRgba(
  GCanvasRenderer renderer,
  GStage stage,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  renderer.render(ui.Canvas(recorder), stage);
  final picture = recorder.endRecording();
  try {
    final output = await picture.toImage(width, height);
    try {
      final bytes = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(bytes!.buffer.asUint8List());
    } finally {
      output.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void _expectRgba(Uint8List rgba, int width, int x, int y, List<int> expected) {
  final offset = (y * width + x) * 4;
  expect(rgba.sublist(offset, offset + 4), expected);
}

Future<ui.Image> _atlasImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 2, 2),
    ui.Paint()..color = const ui.Color(0xffff0000),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(2, 0, 2, 2),
    ui.Paint()..color = const ui.Color(0xff00ff00),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(4, 2);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _image(
  int width,
  int height, [
  ui.Color color = const ui.Color(0xffffffff),
]) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}
