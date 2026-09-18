import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('pathStroke uses explicit interaction width', () {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0);
    final area = GHitArea.pathStroke(path, 20);

    expect(area.contains(50, 9.9), isTrue);
    expect(area.contains(50, 10.1), isFalse);
    expect(area.contains(-9, 0), isTrue);
    expect(area.contains(-11, 0), isFalse);
  });

  test('pathStroke follows curved geometry instead of path bounds', () {
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(50, 100, 100, 0);
    final area = GHitArea.pathStroke(path, 10);

    expect(area.contains(50, 50), isTrue);
    expect(area.contains(50, 10), isFalse);
  });

  test('pathStroke snapshots caller path', () {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(50, 0);
    final area = GHitArea.pathStroke(path, 10);
    path.lineTo(100, 0);

    expect(area.contains(25, 0), isTrue);
    expect(area.contains(75, 0), isFalse);
  });

  test('empty and zero-length stroke contours stay empty', () {
    for (final path in <Path>[
      Path(),
      Path()
        ..moveTo(10, 20)
        ..lineTo(10, 20),
    ]) {
      final area = GPathStrokeHitArea(path, 10);
      final bounds = GBounds.empty();
      area.getApproximateBounds(bounds);

      expect(bounds.isEmpty, isTrue);
      expect(area.contains(10, 20), isFalse);
      expect(area.distanceSquaredTo(10, 20), double.infinity);
    }
  });

  test('repeated points do not disturb a real stroke segment', () {
    final area = GPathStrokeHitArea(
      Path()
        ..moveTo(0, 0)
        ..lineTo(0, 0)
        ..lineTo(100, 0)
        ..lineTo(100, 0),
      20,
    );
    final bounds = GBounds.empty();
    area.getApproximateBounds(bounds);

    expect(area.contains(50, 9.9), isTrue);
    expect(area.contains(50, 10.1), isFalse);
    expect(bounds.x1, closeTo(-10, 1e-6));
    expect(bounds.x2, closeTo(110, 1e-6));
    expect(bounds.y1, closeTo(-10, 1e-6));
    expect(bounds.y2, closeTo(10, 1e-6));
  });

  test('stroke cache bounds follow sampled curve rather than control hull', () {
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(0, 100, 100, 100, 100, 0);
    final area = GPathStrokeHitArea(path, 10);
    final bounds = GBounds.empty();

    area.getApproximateBounds(bounds);

    expect(bounds.y1, closeTo(-5, 0.1));
    expect(bounds.y2, closeTo(80, 1));
    expect(bounds.y2, lessThan(90));
  });

  test('stroke distance exposes the same nearest-segment calculation', () {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0);
    final area = GPathStrokeHitArea(path, 20);
    final nearest = GPoint();

    final distanceSq = area.distanceSquaredTo(50, 7, nearest);

    expect(distanceSq, closeTo(49, 1e-6));
    expect(nearest.x, closeTo(50, 1e-6));
    expect(nearest.y, closeTo(0, 1e-6));
  });

  test('graphics strokeHitArea uses only stroked batches', () {
    final shape = GShape();
    shape.graphics
      ..beginFill(const Color(0xffffffff))
      ..drawRect(0, 0, 40, 40)
      ..endFill()
      ..lineStyle(1, const Color(0xffffffff))
      ..drawLine(100, 0, 200, 0)
      ..endStroke();

    final area = shape.graphics.strokeHitArea(20);
    expect(area.contains(20, 20), isFalse);
    expect(area.contains(150, 9), isTrue);
    expect(area.contains(150, 11), isFalse);
    shape.dispose();
  });

  test('graphics strokeHitArea follows later retained geometry changes', () {
    final shape = GShape();
    shape.graphics
      ..lineStyle(1, const Color(0xffffffff))
      ..moveTo(0, 0)
      ..lineTo(50, 0);
    final area = shape.graphics.strokeHitArea(12);

    expect(area.contains(25, 0), isTrue);
    expect(area.contains(75, 0), isFalse);

    shape.graphics.lineTo(100, 0);
    expect(area.contains(75, 0), isTrue);

    shape.graphics.clear();
    expect(area.contains(25, 0), isFalse);
    shape.dispose();
  });

  test('stroke hit width must be positive and finite', () {
    final path = Path()..lineTo(10, 0);
    expect(() => GHitArea.pathStroke(path, 0), throwsArgumentError);
    expect(
      () => GHitArea.pathStroke(path, double.infinity),
      throwsArgumentError,
    );

    final shape = GShape();
    expect(() => shape.graphics.strokeHitArea(-1), throwsArgumentError);
    shape.dispose();
  });
}
