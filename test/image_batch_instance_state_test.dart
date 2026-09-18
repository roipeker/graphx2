import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('instance pivot affects bounds around registration point', () async {
    final image = await _image();
    final texture = GTexture(image);
    final batch = GImageBatch();
    final item = batch.add(texture, x: 20, y: 30, pivotX: 2, pivotY: 3);

    final bounds = batch.localBounds;
    expect(bounds.x1, 18);
    expect(bounds.y1, 27);
    expect(bounds.x2, 22);
    expect(bounds.y2, 31);

    item.setPivot(0, 0);
    final moved = batch.localBounds;
    expect(moved.x1, 20);
    expect(moved.y1, 30);
    expect(moved.x2, 24);
    expect(moved.y2, 34);

    batch.dispose();
    texture.dispose();
    image.dispose();
  });

  test('color storage stays lazy until instance color state is used', () async {
    final image = await _image();
    final texture = GTexture(image);
    final batch = GImageBatch(capacity: 8);
    final a = batch.add(texture);
    batch.add(texture, x: 10);

    expect(batch.usesInstanceColors, isFalse);
    a.alpha = .5;
    expect(batch.usesInstanceColors, isTrue);
    expect(a.alpha, .5);

    a.color = const ui.Color(0xffff8844);
    expect(a.color, const ui.Color(0xffff8844));

    batch.dispose();
    texture.dispose();
    image.dispose();
  });

  test('pivot color and alpha survive compaction', () async {
    final image = await _image();
    final texture = GTexture(image);
    final batch = GImageBatch();
    final first = batch.add(texture, color: const ui.Color(0xffff0000));
    final keep = batch.add(
      texture,
      x: 10,
      pivotX: 2,
      pivotY: 1,
      alpha: .4,
      color: const ui.Color(0xff00ff00),
    );

    first.remove();
    expect(keep.isAttached, isTrue);
    expect(keep.x, 10);
    expect(keep.pivotX, 2);
    expect(keep.pivotY, 1);
    expect(keep.alpha, .4);
    expect(keep.color, const ui.Color(0xff00ff00));

    keep.x = 12;
    expect(batch[0], same(keep));

    batch.dispose();
    texture.dispose();
    image.dispose();
  });
}

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xffffffff),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(4, 4);
  } finally {
    picture.dispose();
  }
}
