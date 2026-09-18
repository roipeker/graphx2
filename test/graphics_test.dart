import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('Flash-style fill/stroke grammar produces canonical bounds', () {
    final shape = GShape();
    shape.graphics
      ..beginFill(const Color(0xffff0000))
      ..lineStyle(
        4,
        const Color(0xffffffff),
        true,
        StrokeCap.butt,
        StrokeJoin.round,
      )
      ..drawRect(10, 20, 100, 40)
      ..endFill();

    final out = GBounds.empty();
    shape.getLocalBounds(out);
    expect((out.x1, out.y1, out.x2, out.y2), (8, 18, 112, 62));
  });

  test('sampled Graphics bounds are opt-in and tighter for cubic curves', () {
    final shape = GShape();
    shape.graphics
      ..lineStyle(
        2,
        const Color(0xffffffff),
        true,
        StrokeCap.round,
        StrokeJoin.round,
      )
      ..moveTo(0, 0)
      ..cubicCurveTo(0, 100, 100, 100, 100, 0);

    final canonical = GBounds.empty();
    final sampled = GBounds.empty();
    shape.getLocalBounds(canonical);
    shape.graphics.computeApproximateBounds(sampled, sampleStep: 0.5);

    expect(canonical.y2, greaterThan(99));
    expect(sampled.y2, closeTo(76, 1));
    expect(sampled.y2, lessThan(canonical.y2 - 20));
    shape.dispose();
  });

  test('sampled Graphics bounds clear output for empty geometry', () {
    final shape = GShape();
    final out = GBounds(1, 2, 3, 4);

    shape.graphics.computeApproximateBounds(out);
    expect(out.isEmpty, isTrue);

    shape.graphics
      ..lineStyle(2, const Color(0xffffffff))
      ..moveTo(10, 20)
      ..lineTo(10, 20);
    out.set(1, 2, 3, 4);
    shape.graphics.computeApproximateBounds(out);
    expect(out.isEmpty, isTrue);
    shape.dispose();
  });

  test('sampled Graphics bounds reject invalid sample steps', () {
    final shape = GShape();
    shape.graphics
      ..beginFill(const Color(0xffffffff))
      ..drawRect(0, 0, 10, 10)
      ..endFill();
    final out = GBounds.empty();

    expect(
      () => shape.graphics.computeApproximateBounds(out, sampleStep: 0),
      throwsArgumentError,
    );
    shape.dispose();
  });

  test('fill hit testing follows actual path rather than only bounds', () {
    final shape = GShape();
    shape.graphics
      ..beginFill(const Color(0xff00ff00))
      ..drawCircle(50, 50, 40)
      ..endFill();

    expect(shape.hitTestLocal(50, 50), isTrue);
    expect(shape.hitTestLocal(12, 12), isFalse);
  });

  test('stroke hit testing stays deliberately conservative', () {
    final shape = GShape();
    shape.graphics
      ..lineStyle(
        4,
        const Color(0xffffffff),
        true,
        StrokeCap.butt,
        StrokeJoin.round,
      )
      ..drawLine(0, 0, 100, 0)
      ..endStroke();

    expect(shape.hitTestLocal(50, 1), isTrue);
    expect(shape.hitTestLocal(50, 8), isFalse);
  });

  test('style changes create retained batch boundaries', () {
    final shape = GShape();
    shape.graphics
      ..beginFill(const Color(0xffff0000))
      ..drawRect(0, 0, 10, 10)
      ..beginFill(const Color(0xff0000ff))
      ..drawRect(20, 0, 10, 10)
      ..endFill();

    expect(shape.graphics.batchCount, 2);
    final out = shape.getLocalBounds();
    expect((out.x1, out.y1, out.x2, out.y2), (0, 0, 30, 10));
  });

  test('graphics mutation invalidates cached ancestor bounds', () {
    final parent = GNode();
    final shape = parent.addChild(GShape())
      ..x = 10
      ..y = 5;
    shape.graphics
      ..beginFill(const Color(0xffffffff))
      ..drawRect(0, 0, 20, 10)
      ..endFill();

    final out = GBounds.empty();
    parent.getLocalBounds(out);
    expect((out.x1, out.y1, out.x2, out.y2), (10, 5, 30, 15));

    shape.graphics.redraw((g) {
      g
        ..beginFill(const Color(0xffffffff))
        ..drawRect(0, 0, 50, 30)
        ..endFill();
    });

    parent.getLocalBounds(out);
    expect((out.x1, out.y1, out.x2, out.y2), (10, 5, 60, 35));
  });

  test('clear removes retained geometry, bounds, and generated shaders', () {
    final shape = GShape();
    shape.graphics
      ..beginGradientFill(GGradientType.linear, const [
        Color(0xffff0066),
        Color(0xff00ddff),
      ])
      ..drawRect(0, 0, 20, 10)
      ..endFill();

    _paint(shape);
    expect(shape.getLocalBounds().isEmpty, isFalse);
    shape.graphics.clear();
    expect(shape.getLocalBounds().isEmpty, isTrue);
    expect(shape.graphics.batchCount, 0);
    _paint(shape);
    shape.dispose();
  });

  test('gradient shader is retained across unchanged paints', () {
    final shape = GShape();
    shape.graphics
      ..beginGradientFill(GGradientType.radial, const [
        Color(0xffffffff),
        Color(0xff000000),
      ])
      ..drawCircle(20, 20, 20)
      ..endFill();

    expect(() {
      _paint(shape);
      _paint(shape);
      _paint(shape);
    }, returnsNormally);
    shape.dispose();
  });

  test('gradient and solid stroke share the retained path batch', () {
    final shape = GShape();
    shape.graphics
      ..beginGradientFill(GGradientType.linear, const [
        Color(0xffff0066),
        Color(0xff00ddff),
      ])
      ..lineStyle(
        2,
        const Color(0xffffffff),
        true,
        StrokeCap.round,
        StrokeJoin.round,
      )
      ..drawRoundRect(0, 0, 120, 48, 12)
      ..endFill();

    expect(shape.graphics.batchCount, 1);
    final out = shape.getLocalBounds();
    expect((out.x1, out.y1, out.x2, out.y2), (-1, -1, 121, 49));
  });

  test('externally supplied shader remains caller-owned', () {
    final shader = ui.Gradient.linear(
      ui.Offset.zero,
      const ui.Offset(100, 0),
      const [Color(0xffff0066), Color(0xff00ddff)],
    );
    final shape = GShape();
    shape.graphics
      ..beginPaintShaderFill(shader)
      ..drawRect(5, 7, 100, 40)
      ..endFill();

    _paint(shape);
    shape.dispose();

    expect(() {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 10, 10),
        ui.Paint()..shader = shader,
      );
      recorder.endRecording().dispose();
    }, returnsNormally);
    shader.dispose();
  });

  test(
    'bitmap fill accepts full GTexture and preserves logical bounds',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 32, 32),
        ui.Paint()..color = const Color(0xffffffff),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(32, 32);
      picture.dispose();
      final texture = GTexture.owned(image, scale: 2);

      final shape = GShape();
      shape.graphics
        ..beginBitmapFill(texture, null, true, true)
        ..drawRect(0, 0, 80, 50)
        ..endFill();

      final out = shape.getLocalBounds();
      expect((out.x1, out.y1, out.x2, out.y2), (0, 0, 80, 50));
      _paint(shape);
      shape.dispose();
      expect(texture.isDisposed, isFalse);
      texture.dispose();
    },
  );

  test('bitmap fill clear releases shader but not source texture', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(16, 16);
    picture.dispose();
    final texture = GTexture.owned(image);
    final shape = GShape();

    shape.graphics
      ..beginBitmapFill(texture, null, true, false)
      ..drawRect(0, 0, 32, 32)
      ..endFill();
    _paint(shape);
    shape.graphics.clear();

    expect(texture.isDisposed, isFalse);
    expect(shape.graphics.batchCount, 0);
    shape.dispose();
    texture.dispose();
  });

  test(
    'bitmap fill rejects atlas-region texture until sampling is truthful',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint()..color = const Color(0x00000000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(32, 32);
      picture.dispose();
      final root = GTexture.owned(image);
      final region = root.region(region: GRect(0, 0, 16, 16));
      final shape = GShape();

      expect(
        () => shape.graphics.beginBitmapFill(region),
        throwsA(isA<UnsupportedError>()),
      );
      shape.dispose();
      root.dispose();
    },
  );
}

void _paint(GShape shape) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  shape.graphics.paint(canvas, 1);
  recorder.endRecording().dispose();
}
