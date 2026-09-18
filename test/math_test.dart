// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  group('Math', () {
    test('degree and radian helpers cover the old conversion utilities', () {
      expect(GMath.radians(180), closeTo(GMath.pi, 1e-12));
      expect(GMath.degrees(GMath.pi), closeTo(180, 1e-12));
    });

    test('wrap normalizes positive and negative values', () {
      expect(GMath.wrap(370, 360), closeTo(10, 1e-12));
      expect(GMath.wrap(-10, 360), closeTo(350, 1e-12));
      expect(GMath.wrap(-360, 360), 0);
    });

    test('cyclic lerp takes the shortest wrapped path', () {
      expect(GMath.lerpCyclic(350, 10, 0.5, 360), closeTo(0, 1e-12));
      expect(GMath.lerpCyclic(10, 350, 0.5, 360), closeTo(0, 1e-12));
    });

    test('cyclic lerp normalizes out-of-range endpoints', () {
      expect(GMath.lerpCyclic(710, 370, 0.5, 360), closeTo(0, 1e-12));
      expect(GMath.lerpCyclic(-10, 10, 0.5, 360), closeTo(0, 1e-12));
    });

    test('inverse lerp remains intentionally unclamped', () {
      expect(GMath.invLerp(10, 20, 5), closeTo(-0.5, 1e-12));
      expect(GMath.invLerp(10, 20, 25), closeTo(1.5, 1e-12));
      expect(GMath.invLerp(10, 10, 100), 0);
    });
  });

  group('Geometry', () {
    test('default rectangles are independent empty mutable values', () {
      final first = GRect();
      final second = GRect();

      first.set(1, 2, 3, 4);

      expect(first.isEmpty, isFalse);
      expect(second.isEmpty, isTrue);
      expect(second.x, 0);
      expect(second.y, 0);
      expect(second.w, 0);
      expect(second.h, 0);
    });

    test('empty rectangles never intersect non-empty rectangles', () {
      final area = GRect(0, 0, 100, 100);

      expect(GRect().intersects(area), isFalse);
      expect(GRect(50, 50, 0, 10).intersects(area), isFalse);
      expect(area.intersects(GRect(50, 50, 10, 0)), isFalse);
      expect(GRect(25, 25, 10, 10).intersects(area), isTrue);
    });
  });
}
