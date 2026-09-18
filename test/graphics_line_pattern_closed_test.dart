import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test(
    'closed patterns fit spacing so the contour seam has no extra motif',
    () {
      final pattern = GLinePattern(
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 2)),
        advance: 55,
        filled: true,
      );
      final shape = GShape();
      shape.graphics
        ..lineStyle(1, const Color(0xffffffff))
        ..linePattern(pattern)
        ..drawPath(Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100)));

      // Perimeter = 400. A requested advance of 55 fits seven anchors at
      // 400 / 7 ~= 57.14 rather than placing an eighth anchor 15 px before the
      // seam. That keeps motif count constant as phase wraps around the loop.
      expect(shape.hitTestLocal(0, 15), isFalse);
      expect(shape.hitTestLocal(0, 57), isTrue);

      const fittedAdvance = 400 / 7;
      pattern.phase = fittedAdvance - .5;
      expect(shape.hitTestLocal(0, 0), isTrue);
      pattern.phase = fittedAdvance + .5;
      expect(shape.hitTestLocal(0, 0), isTrue);

      shape.dispose();
    },
  );

  test('closed tangent alignment crosses a sharp seam continuously', () {
    final loop = Path()
      ..moveTo(0, 0)
      ..lineTo(40, 0)
      ..lineTo(40, 40)
      ..lineTo(0, 40)
      ..close();
    final pattern = GLinePattern(
      Path()..addRect(const Rect.fromLTWH(0, -1, 10, 2)),
      advance: 1000,
      filled: true,
    );
    final shape = GShape();
    shape.graphics
      ..lineStyle(1, const Color(0xffffffff))
      ..linePattern(pattern)
      ..drawPath(loop);

    // At the closed seam the incoming tangent points up and the outgoing
    // tangent points right. The motif should take the short continuous
    // transition between them instead of snapping to either segment for one
    // generated frame.
    expect(shape.hitTestLocal(5, -5), isTrue);
    expect(shape.hitTestLocal(6, 0), isFalse);

    shape.dispose();
  });
}
