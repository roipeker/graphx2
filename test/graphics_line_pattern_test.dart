import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('lineDash requires an active line style', () {
    final shape = GShape();
    expect(() => shape.graphics.lineDash(const [8, 4]), throwsStateError);
    shape.dispose();
  });

  test(
    'lineDash stays in one retained batch and uses derived stroke bounds',
    () {
      final shape = GShape();
      shape.graphics
        ..lineStyle(4, const Color(0xffffffff), true, StrokeCap.butt)
        ..lineDash(const [12, 6])
        ..drawLine(0, 0, 100, 0);

      expect(shape.graphics.batchCount, 1);
      final bounds = shape.getLocalBounds();
      expect(bounds.x1, -6);
      expect(bounds.y1, -6);
      expect(bounds.x2, 106);
      expect(bounds.y2, 6);

      expect(() {
        for (var i = 0; i < 20; ++i) {
          _paint(shape.graphics);
        }
      }, returnsNormally);
      expect(shape.graphics.batchCount, 1);
      shape.dispose();
    },
  );

  test(
    'odd dash lists are accepted and clearing dash restores solid stroke',
    () {
      final shape = GShape();
      shape.graphics
        ..lineStyle(2, const Color(0xffffffff))
        ..lineDash(const [8, 3, 2])
        ..drawLine(0, 0, 40, 0)
        ..lineDash(null)
        ..drawLine(0, 20, 40, 20);

      expect(shape.graphics.batchCount, 2);
      expect(() => _paint(shape.graphics), returnsNormally);
      shape.dispose();
    },
  );

  test(
    'linePattern copies motif geometry and uses conservative retained bounds',
    () {
      final motif = Path()
        ..moveTo(-4, -8)
        ..lineTo(8, 0)
        ..lineTo(-4, 8);
      final pattern = GLinePattern(motif, advance: 24);

      // Mutating the caller-owned path after construction must not affect stamps.
      motif.addRect(const Rect.fromLTWH(1000, 1000, 100, 100));

      final shape = GShape();
      shape.graphics
        ..lineStyle(2, const Color(0xffffffff), true, StrokeCap.round)
        ..linePattern(pattern)
        ..drawLine(0, 0, 96, 0);

      final bounds = shape.getLocalBounds();
      expect(bounds.x1, lessThanOrEqualTo(-9));
      expect(bounds.x2, lessThan(111));
      expect(bounds.y1, lessThanOrEqualTo(-9));
      expect(bounds.y2, greaterThanOrEqualTo(9));
      expect(() => _paint(shape.graphics), returnsNormally);
      shape.dispose();
    },
  );

  test('filled motifs ignore stroke width and retain conservative bounds', () {
    final pattern = GLinePattern(
      Path()
        ..moveTo(-6, -4)
        ..lineTo(6, 0)
        ..lineTo(-6, 4)
        ..close(),
      advance: 20,
      filled: true,
    );
    final shape = GShape();
    shape.graphics
      ..lineStyle(40, const Color(0xffffffff))
      ..linePattern(pattern)
      ..drawLine(0, 0, 40, 0);

    final bounds = shape.getLocalBounds();
    expect(bounds.x1, greaterThan(-8));
    expect(bounds.x1, lessThan(-7));
    expect(bounds.x2, greaterThan(47));
    expect(bounds.x2, lessThan(48));
    expect(bounds.y1, greaterThan(-8));
    expect(bounds.y1, lessThan(-7));
    expect(shape.hitTestLocal(0, 0), isTrue);
    expect(shape.hitTestLocal(0, 10), isFalse);
    expect(() => _paint(shape.graphics), returnsNormally);
    shape.dispose();
  });

  test(
    'mutable pattern phase moves forward without rebuilding source batch',
    () {
      final pattern = GLinePattern(
        Path()..addRect(const Rect.fromLTWH(-2, -2, 4, 4)),
        advance: 20,
        filled: true,
      );
      final shape = GShape();
      shape.graphics
        ..lineStyle(1, const Color(0xffffffff))
        ..linePattern(pattern)
        ..drawLine(0, 0, 60, 0);

      _paint(shape.graphics);
      final before = shape.getLocalBounds();
      expect(shape.hitTestLocal(0, 0), isTrue);
      expect(shape.graphics.batchCount, 1);

      pattern.phase = 5;

      // Positive phase advances motif anchors from 0,20,... to 5,25,... .
      expect(shape.hitTestLocal(0, 0), isFalse);
      expect(shape.hitTestLocal(5, 0), isTrue);
      expect(shape.graphics.batchCount, 1);
      final after = shape.getLocalBounds();
      expect(
        (after.x1, after.y1, after.x2, after.y2),
        (before.x1, before.y1, before.x2, before.y2),
      );
      expect(() => _paint(shape.graphics), returnsNormally);
      shape.dispose();
    },
  );

  test('pattern pivot uses GPoint and is copied at construction', () {
    final pivot = GPoint(10, 0);
    final pattern = GLinePattern(
      Path()..addRect(const Rect.fromLTWH(8, -2, 4, 4)),
      advance: 20,
      pivot: pivot,
      filled: true,
    );
    pivot.set(100, 100);

    final shape = GShape();
    shape.graphics
      ..lineStyle(1, const Color(0xffffffff))
      ..linePattern(pattern)
      ..drawLine(0, 0, 40, 0);

    expect(shape.hitTestLocal(0, 0), isTrue);
    expect(shape.hitTestLocal(10, 0), isFalse);
    expect(pattern.pivot.x, 10);
    expect(pattern.pivot.y, 0);
    shape.dispose();
  });

  test('pattern rotation aligns authored motif axis with source tangent', () {
    final pattern = GLinePattern(
      Path()..addRect(const Rect.fromLTWH(-1, -8, 2, 8)),
      advance: 20,
      rotation: Math.halfPi,
      filled: true,
    );
    final shape = GShape();
    shape.graphics
      ..lineStyle(1, const Color(0xffffffff))
      ..linePattern(pattern)
      ..drawLine(0, 0, 40, 0);

    // The motif is authored upward. +pi/2 rotates it onto +X, the tangent of
    // this horizontal source path.
    expect(shape.hitTestLocal(7, 0), isTrue);
    expect(shape.hitTestLocal(0, -7), isFalse);
    shape.dispose();
  });

  test('tangent alignment follows source direction on diagonal paths', () {
    final pattern = GLinePattern(
      Path()..addRect(const Rect.fromLTWH(0, -1, 10, 2)),
      advance: 100,
      filled: true,
    );

    final downRight = GShape();
    downRight.graphics
      ..lineStyle(1, const Color(0xffffffff))
      ..linePattern(pattern)
      ..drawLine(0, 0, 20, 20);
    expect(downRight.hitTestLocal(5, 5), isTrue);
    expect(downRight.hitTestLocal(5, -5), isFalse);
    downRight.dispose();

    final upRight = GShape();
    upRight.graphics
      ..lineStyle(1, const Color(0xffffffff))
      ..linePattern(pattern)
      ..drawLine(0, 0, 20, -20);
    expect(upRight.hitTestLocal(5, -5), isTrue);
    expect(upRight.hitTestLocal(5, 5), isFalse);
    upRight.dispose();
  });

  test('pattern phase can legitimately produce no stamped geometry', () {
    final pattern = GLinePattern(
      Path()
        ..moveTo(-2, -2)
        ..lineTo(4, 0)
        ..lineTo(-2, 2),
      advance: 20,
    );
    final shape = GShape();
    shape.graphics
      ..lineStyle(2, const Color(0xffffffff))
      ..linePattern(pattern, phase: 5)
      ..drawLine(100, 100, 105, 100);

    expect(shape.hitTestLocal(0, 0), isFalse);
    expect(() => _paint(shape.graphics), returnsNormally);
    shape.dispose();
  });

  test('fixed and tangent motif alignments accept curved and closed paths', () {
    final motif = Path()
      ..moveTo(-5, -5)
      ..lineTo(7, 0)
      ..lineTo(-5, 5);

    for (final alignment in GLinePatternAlignment.values) {
      final shape = GShape();
      shape.graphics
        ..lineStyle(2, const Color(0xffffffff))
        ..linePattern(
          GLinePattern(motif, advance: 18, alignment: alignment),
          phase: 5,
        )
        ..moveTo(-40, 0)
        ..cubicCurveTo(-20, -50, 20, 50, 40, 0)
        ..drawCircle(0, 0, 28);
      expect(() => _paint(shape.graphics), returnsNormally);
      expect(shape.getLocalBounds().isEmpty, isFalse);
      shape.dispose();
    }
  });

  test('dash and pattern validation rejects invalid geometry state', () {
    final shape = GShape();
    shape.graphics.lineStyle(2, const Color(0xffffffff));

    expect(() => shape.graphics.lineDash(const [8, 0]), throwsArgumentError);
    expect(
      () => shape.graphics.lineDash(const [double.infinity]),
      throwsArgumentError,
    );
    expect(
      () => shape.graphics.lineDash(const [8, 4], phase: double.nan),
      throwsArgumentError,
    );
    expect(() => GLinePattern(Path(), advance: 0), throwsArgumentError);
    expect(
      () => GLinePattern(Path(), advance: 10, phase: double.nan),
      throwsArgumentError,
    );
    expect(
      () =>
          GLinePattern(Path(), advance: 10, pivot: GPoint(double.infinity, 0)),
      throwsArgumentError,
    );
    expect(
      () => GLinePattern(Path(), advance: 10, rotation: double.nan),
      throwsArgumentError,
    );
    shape.dispose();
  });
}

void _paint(GGraphics graphics) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  graphics.paint(canvas, 1);
  recorder.endRecording().dispose();
}
