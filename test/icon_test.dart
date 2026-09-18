// Copyright (c) 2026 GraphX by roipeker.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('icon uses deterministic square bounds', () {
    final icon = GIcon(Icons.settings, size: 32);

    final before = icon.getLocalBounds();
    expect(before.width, 32);
    expect(before.height, 32);

    icon.data = Icons.favorite;
    final afterGlyph = icon.getLocalBounds();
    expect(afterGlyph.width, 32);
    expect(afterGlyph.height, 32);

    icon.size = 48;
    final afterSize = icon.getLocalBounds();
    expect(afterSize.width, 48);
    expect(afterSize.height, 48);
  });

  test('glyph constructor preserves icon font metadata', () {
    final source = Icons.play_arrow;
    final icon = GIcon.glyph(
      source.codePoint,
      fontFamily: source.fontFamily,
      fontPackage: source.fontPackage,
      fontFamilyFallback: source.fontFamilyFallback,
      matchTextDirection: source.matchTextDirection,
      size: 28,
      color: Colors.green,
    );

    expect(icon.data, isNull);
    expect(icon.codePoint, source.codePoint);
    expect(icon.fontFamily, source.fontFamily);
    expect(icon.fontPackage, source.fontPackage);
    expect(icon.fontFamilyFallback, source.fontFamilyFallback);
    expect(icon.matchTextDirection, source.matchTextDirection);
    expect(icon.size, 28);
    expect(icon.color, Colors.green);
  });

  test('all mutable icon properties update retained state', () {
    final icon = GIcon(Icons.arrow_back, direction: TextDirection.ltr);

    icon
      ..color = Colors.red
      ..size = 30
      ..direction = TextDirection.rtl
      ..data = Icons.arrow_forward;

    expect(icon.data, Icons.arrow_forward);
    expect(icon.codePoint, Icons.arrow_forward.codePoint);
    expect(icon.color, Colors.red);
    expect(icon.size, 30);
    expect(icon.direction, TextDirection.rtl);

    icon
      ..codePoint = 0x41
      ..fontFamily = 'TestIcons'
      ..fontPackage = 'test_package'
      ..fontFamilyFallback = const ['Arial', 'sans-serif']
      ..matchTextDirection = true;

    expect(icon.data, isNull);
    expect(icon.codePoint, 0x41);
    expect(icon.fontFamily, 'TestIcons');
    expect(icon.fontPackage, 'test_package');
    expect(icon.fontFamilyFallback, const ['Arial', 'sans-serif']);
    expect(icon.matchTextDirection, isTrue);
  });

  test('foreground and shadows stay paint-only and preserve bounds', () {
    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.pink;
    const shadows = [
      Shadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(2, 2)),
    ];
    final icon = GIcon(
      Icons.star,
      size: 40,
      foreground: foreground,
      shadows: shadows,
    );

    final before = icon.getLocalBounds();
    expect(icon.foreground, same(foreground));
    expect(icon.shadows, shadows);

    icon.shadows = const [Shadow(color: Colors.blue, blurRadius: 2)];
    final after = icon.getLocalBounds();

    expect(after.width, before.width);
    expect(after.height, before.height);
  });

  test('solid color and foreground switch the active paint path', () {
    final paint = Paint()..color = Colors.purple;
    final icon = GIcon(Icons.bolt, foreground: paint);

    expect(icon.foreground, same(paint));
    icon.color = Colors.green;
    expect(icon.foreground, isNull);
    expect(icon.color, Colors.green);

    icon.foreground = paint;
    expect(icon.foreground, same(paint));
    expect(icon.color, GIcon.defaultStyle.color);
  });

  test('constructor rejects simultaneous color and foreground', () {
    expect(
      () => GIcon(Icons.add, color: Colors.red, foreground: Paint()),
      throwsArgumentError,
    );
  });

  test('raw glyph paints actual pixels', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final context = GRenderContext();
    context.canvas = canvas;

    final icon = GIcon.glyph(0x41, size: 32, color: Colors.red);
    icon.paintSelf(context);

    final picture = recorder.endRecording();
    final image = await picture.toImage(32, 32);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();

    var painted = false;
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i] > 0 && bytes[i + 3] > 0) {
        painted = true;
        break;
      }
    }
    expect(painted, isTrue);

    image.dispose();
    icon.dispose();
    context.dispose();
  });

  test('invalid glyph inputs are rejected', () {
    expect(() => GIcon(Icons.add, size: -1), throwsArgumentError);
    expect(() => GIcon(Icons.add, size: double.infinity), throwsArgumentError);
    expect(() => GIcon.glyph(-1), throwsArgumentError);
    expect(() => GIcon.glyph(0x110000), throwsArgumentError);

    final icon = GIcon(Icons.add);
    expect(() => icon.size = double.nan, throwsArgumentError);
    expect(() => icon.codePoint = -1, throwsArgumentError);
  });
}
