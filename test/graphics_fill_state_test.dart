import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('last beginFill wins before geometry', () {
    final shape = GShape();
    shape.graphics
      ..beginFill(const Color(0xffff0000))
      ..beginFill(const Color(0xff00ff00))
      ..beginFill(const Color(0xff0000ff))
      ..drawRect(0, 0, 20, 10)
      ..endFill();

    expect(shape.graphics.batchCount, 1);
    final bounds = shape.getLocalBounds();
    expect((bounds.x1, bounds.y1, bounds.x2, bounds.y2), (0, 0, 20, 10));
    shape.dispose();
  });

  test('unused bitmap fill can be replaced without owning texture', () async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    picture.dispose();
    final texture = GTexture.owned(image);
    final shape = GShape();

    shape.graphics
      ..beginBitmapFill(texture)
      ..beginFill(const Color(0xffffffff))
      ..drawRect(0, 0, 10, 10)
      ..endFill();

    expect(shape.graphics.batchCount, 1);
    shape.dispose();
    expect(texture.isDisposed, isFalse);
    texture.dispose();
  });

  test('GGradient creates caller-owned shader for beginShaderFill', () {
    final shader = GGradient.radial(Offset.zero, 20, const [
      Color(0xffffffff),
      Color(0x00ffffff),
    ]);
    final shape = GShape();
    shape.graphics
      ..beginPaintShaderFill(shader)
      ..drawCircle(0, 0, 20)
      ..endFill();

    shape.dispose();
    expect(() => shader.dispose(), returnsNormally);
  });
}
