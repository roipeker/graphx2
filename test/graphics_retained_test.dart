import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('last lineStyle wins before geometry', () {
    final shape = GShape();
    shape.graphics
      ..lineStyle(2, const Color(0xffff0000))
      ..lineStyle(6, const Color(0xff00ff00))
      ..lineStyle(10, const Color(0xff0000ff))
      ..drawLine(0, 0, 100, 0)
      ..endStroke();

    expect(shape.graphics.batchCount, 1);
    final bounds = shape.getLocalBounds();
    expect(bounds.x1, -15);
    expect(bounds.y1, -15);
    expect(bounds.x2, 115);
    expect(bounds.y2, 15);
    shape.dispose();
  });

  test('retained gradient survives geometry append and updates bounds', () {
    final shape = GShape();
    shape.graphics
      ..beginGradientFill(GGradientType.linear, const [
        Color(0xffff0066),
        Color(0xff00ddff),
      ])
      ..drawRect(0, 0, 20, 10);

    _paint(shape.graphics, 1);
    expect(shape.graphics.batchCount, 1);
    var bounds = shape.getLocalBounds();
    expect((bounds.x1, bounds.y1, bounds.x2, bounds.y2), (0, 0, 20, 10));

    shape.graphics.drawRect(40, 0, 20, 10);
    _paint(shape.graphics, 1);
    bounds = shape.getLocalBounds();
    expect((bounds.x1, bounds.y1, bounds.x2, bounds.y2), (0, 0, 60, 10));
    expect(shape.graphics.batchCount, 1);
    shape.dispose();
  });

  test('stable shader alpha supports repeated retained paints', () {
    final shader = GGradient.radial(Offset.zero, 32, const [
      Color(0xffffffff),
      Color(0x00ffffff),
    ]);
    final shape = GShape();
    shape.graphics
      ..beginPaintShaderFill(shader)
      ..drawCircle(0, 0, 32)
      ..endFill();

    expect(() {
      for (var i = 0; i < 100; ++i) {
        _paint(shape.graphics, .45);
      }
    }, returnsNormally);

    shape.dispose();
    shader.dispose();
  });

  test('cached stroke hit bounds remain correct after geometry append', () {
    final shape = GShape();
    shape.graphics
      ..lineStyle(4, const Color(0xffffffff))
      ..drawLine(0, 0, 20, 0);

    expect(shape.hitTestLocal(10, 1), isTrue);
    expect(shape.hitTestLocal(50, 1), isFalse);

    shape.graphics.drawLine(40, 0, 60, 0);
    expect(shape.hitTestLocal(50, 1), isTrue);
    expect(shape.getLocalBounds().x2, 66);
    shape.dispose();
  });

  test('clear after retained shader paint resets geometry cleanly', () {
    final shape = GShape();
    shape.graphics
      ..beginGradientFill(GGradientType.radial, const [
        Color(0xffffffff),
        Color(0xff000000),
      ])
      ..drawCircle(20, 20, 20)
      ..endFill();

    _paint(shape.graphics, .5);
    shape.graphics.clear();
    expect(shape.graphics.batchCount, 0);
    expect(shape.graphics.isEmpty, isTrue);
    expect(shape.getLocalBounds().isEmpty, isTrue);
    expect(() => _paint(shape.graphics, .5), returnsNormally);
    shape.dispose();
  });
}

void _paint(GGraphics graphics, double alpha) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  graphics.paint(canvas, alpha);
  recorder.endRecording().dispose();
}
