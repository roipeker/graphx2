import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';
import 'package:graphx/graphx_extension.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'instance tint preserves texture transparency and multiplies alpha',
    () async {
      final image = await _image();
      final texture = GTexture(image);
      final batch = GImageBatch()
        ..add(texture, alpha: 0.5, color: const ui.Color(0xff40c080));
      final root = GRoot()..addChild(batch);
      final stage = GStage(root)
        ..mount()
        ..setViewport(2, 1);
      final renderer = GCanvasRenderer();
      final recorder = ui.PictureRecorder();

      renderer.render(ui.Canvas(recorder), stage);
      final picture = recorder.endRecording();
      final output = await picture.toImage(2, 1);
      final bytes = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
      final rgba = bytes!.buffer.asUint8List();

      // The atlas image is the source and the per-instance color is the
      // destination of drawRawAtlas' first blend stage. BlendMode.modulate keeps
      // transparent source pixels transparent while multiplying RGB and alpha.
      expect(rgba[3], 0);
      expect(rgba[7], inInclusiveRange(127, 128));
      expect(rgba[4], lessThan(rgba[6]));
      expect(rgba[6], lessThan(rgba[5]));

      output.dispose();
      picture.dispose();
      renderer.dispose();
      stage.dispose();
      texture.dispose();
      image.dispose();
    },
  );
}

Future<ui.Image> _image() async {
  final pixels = Uint8List.fromList(<int>[
    255,
    255,
    255,
    0,
    255,
    255,
    255,
    255,
  ]);
  final immutable = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    immutable,
    width: 2,
    height: 1,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  immutable.dispose();
  return frame.image;
}
