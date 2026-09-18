// Copyright (c) 2026 GraphX by roipeker.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('GImage uses logical texture size including trim and scale', () {
    final image = _image(64, 64);
    addTearDown(image.dispose);

    final texture = GTexture(
      image,
      scale: 2,
      frame: GTextureFrame(
        region: GRect(8, 12, 24, 16),
        sourceWidth: 40,
        sourceHeight: 28,
        offsetX: 6,
        offsetY: 4,
      ),
    );
    final node = GImage(texture);

    expect(node.width, 20);
    expect(node.height, 14);
    final bounds = node.localBounds;
    expect(bounds.x1, 0);
    expect(bounds.y1, 0);
    expect(bounds.x2, 20);
    expect(bounds.y2, 14);
  });

  test('GImage rejects a disposed texture', () {
    final texture = GTexture.owned(_image(8, 8));
    texture.dispose();

    expect(() => GImage(texture), throwsStateError);
  });

  test('GAnimatedImage advances variable-duration frames', () {
    final textures = _textures(3, 16, 16);
    addTearDown(() => _disposeTextures(textures));
    final sequence = GTextureSequence([
      GTextureSequenceFrame(textures[0], const Duration(milliseconds: 100)),
      GTextureSequenceFrame(textures[1], const Duration(milliseconds: 80)),
      GTextureSequenceFrame(textures[2], const Duration(milliseconds: 120)),
    ]);
    final node = GAnimatedImage(sequence)..play();

    expect(node.frame, 0);
    expect(node.updatesEnabled, isTrue);

    node.update(.11);
    expect(node.frame, 1);

    node.update(.08);
    expect(node.frame, 2);

    node.update(.12);
    expect(node.frame, 0);
    expect(node.playing, isTrue);
  });

  test('GAnimatedImage stop unregisters updates', () {
    final textures = _textures(2, 8, 8);
    addTearDown(() => _disposeTextures(textures));
    final sequence = GTextureSequence([
      GTextureSequenceFrame(textures[0], const Duration(milliseconds: 50)),
      GTextureSequenceFrame(textures[1], const Duration(milliseconds: 50)),
    ]);
    final node = GAnimatedImage(sequence)..play();

    expect(node.updatesEnabled, isTrue);
    node.stop();
    expect(node.playing, isFalse);
    expect(node.updatesEnabled, isFalse);
  });

  test('GAnimatedImage bounds follow current frame size', () {
    final a = GTexture.owned(_image(20, 10));
    final b = GTexture.owned(_image(40, 30));
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final sequence = GTextureSequence([
      GTextureSequenceFrame(a, const Duration(milliseconds: 100)),
      GTextureSequenceFrame(b, const Duration(milliseconds: 100)),
    ]);
    final node = GAnimatedImage(sequence);

    expect(node.width, 20);
    expect(node.height, 10);
    node.frame = 1;
    expect(node.width, 40);
    expect(node.height, 30);
    expect(node.localBounds.x2, 40);
    expect(node.localBounds.y2, 30);
  });

  test('GAnimatedImage completes once when loop is disabled', () {
    final textures = _textures(2, 8, 8);
    addTearDown(() => _disposeTextures(textures));
    final sequence = GTextureSequence([
      GTextureSequenceFrame(textures[0], const Duration(milliseconds: 50)),
      GTextureSequenceFrame(textures[1], const Duration(milliseconds: 50)),
    ]);
    final node = GAnimatedImage(sequence)
      ..loop = false
      ..play();
    var completed = 0;
    node.onComplete.add(() => completed++);

    node.update(.2);

    expect(node.frame, 1);
    expect(node.playing, isFalse);
    expect(node.updatesEnabled, isFalse);
    expect(completed, 1);
  });

  test('GAnimatedImage rejects disposed sequence textures', () {
    final disposed = GTexture.owned(_image(8, 8));
    disposed.dispose();
    final sequence = GTextureSequence([
      GTextureSequenceFrame(disposed, const Duration(milliseconds: 100)),
    ]);

    expect(() => GAnimatedImage(sequence), throwsStateError);
  });
}

ui.Image _image(int width, int height) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xffffffff),
  );
  return recorder.endRecording().toImageSync(width, height);
}

List<GTexture> _textures(int count, int width, int height) =>
    List.generate(count, (_) => GTexture.owned(_image(width, height)));

void _disposeTextures(List<GTexture> textures) {
  for (final texture in textures) {
    texture.dispose();
  }
}
