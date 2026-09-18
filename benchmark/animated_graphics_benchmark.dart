// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';

const _ringCount = 64;
const _sides = 10;
const _logicalWidth = 390.0;
const _logicalHeight = 844.0;
const _dpr = 3.0;
const _warmups = 30;
const _samples = 180;
const _rasterWarmups = 3;
const _rasterSamples = 12;
const _dt = 1 / 60;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('SATECHI ANIMATED GRAPHICS SUITE');
  print(
    '64 retained vector rings · iPhone-sized viewport · DPR 3 raster probe',
  );
  print('times are p50 / p95');
  print('');

  final retained = _RetainedRings();
  await _measure('retained transforms', retained, animateAlpha: false);
  await _measure('retained + alpha', retained, animateAlpha: true);
  retained.dispose();

  final batched = _BatchedRings();
  await _measure('packed line batch', batched);
  batched.dispose();

  print('SATECHI_BENCHMARK_COMPLETE');
  exit(0);
}

Future<void> _measure(
  String label,
  _Scenario scenario, {
  bool animateAlpha = false,
}) async {
  var time = 0.0;
  for (var i = 0; i < _warmups; ++i) {
    time += _dt;
    scenario.update(time, animateAlpha: animateAlpha);
    _record(scenario.renderer, scenario.stage).dispose();
  }

  final updateUs = List<int>.filled(_samples, 0);
  final recordUs = List<int>.filled(_samples, 0);
  for (var i = 0; i < _samples; ++i) {
    time += _dt;

    final updateWatch = Stopwatch()..start();
    scenario.update(time, animateAlpha: animateAlpha);
    updateWatch.stop();
    updateUs[i] = updateWatch.elapsedMicroseconds;

    final recordWatch = Stopwatch()..start();
    final picture = _record(scenario.renderer, scenario.stage);
    recordWatch.stop();
    recordUs[i] = recordWatch.elapsedMicroseconds;
    picture.dispose();
  }

  for (var i = 0; i < _rasterWarmups; ++i) {
    time += _dt;
    scenario.update(time, animateAlpha: animateAlpha);
    final picture = _record(scenario.renderer, scenario.stage, scale: _dpr);
    final image = await picture.toImage(
      (_logicalWidth * _dpr).round(),
      (_logicalHeight * _dpr).round(),
    );
    image.dispose();
    picture.dispose();
  }

  final rasterUs = <int>[];
  for (var i = 0; i < _rasterSamples; ++i) {
    time += _dt;
    scenario.update(time, animateAlpha: animateAlpha);
    final picture = _record(scenario.renderer, scenario.stage, scale: _dpr);
    final rasterWatch = Stopwatch()..start();
    final image = await picture.toImage(
      (_logicalWidth * _dpr).round(),
      (_logicalHeight * _dpr).round(),
    );
    rasterWatch.stop();
    rasterUs.add(rasterWatch.elapsedMicroseconds);
    image.dispose();
    picture.dispose();
  }

  final update = _stats(updateUs);
  final record = _stats(recordUs);
  final raster = _stats(rasterUs);
  print(
    '${label.padRight(22)} '
    'update ${_ms(update.$1)} / ${_ms(update.$2)} ms  '
    'record ${_ms(record.$1)} / ${_ms(record.$2)} ms  '
    'raster@3x ${_ms(raster.$1)} / ${_ms(raster.$2)} ms',
  );
}

ui.Picture _record(GCanvasRenderer renderer, GStage stage, {double scale = 1}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (scale != 1) canvas.scale(scale, scale);
  renderer.render(canvas, stage);
  return recorder.endRecording();
}

(int, int) _stats(List<int> values) {
  values.sort();
  final p50 = values[values.length ~/ 2];
  final p95 = values[(values.length * .95).floor().clamp(0, values.length - 1)];
  return (p50, p95);
}

String _ms(int microseconds) => (microseconds / 1000).toStringAsFixed(3);

abstract interface class _Scenario {
  GStage get stage;
  GCanvasRenderer get renderer;

  void update(double time, {bool animateAlpha = false});
  void dispose();
}

final class _RetainedRings implements _Scenario {
  _RetainedRings() {
    for (var i = 0; i < _ringCount; ++i) {
      final ring = root.addChild(GShape('ring-$i'));
      ring.graphics
        ..lineStyle(
          i.isEven ? 1.2 : .8,
          i.isEven ? const ui.Color(0x997cf7d4) : const ui.Color(0x66a88cff),
          true,
          ui.StrokeCap.round,
          ui.StrokeJoin.round,
        )
        ..moveTo(0, -42);
      for (var vertex = 1; vertex <= _sides; ++vertex) {
        final angle = -math.pi / 2 + math.pi * 2 * vertex / _sides;
        final radius = vertex.isEven ? 42.0 : 35.0;
        ring.graphics.lineTo(
          math.cos(angle) * radius,
          math.sin(angle) * radius,
        );
      }
      ring.graphics.closePath();
      rings.add(ring);
    }

    stage
      ..mount()
      ..setViewport(_logicalWidth, _logicalHeight, devicePixelRatio: _dpr);
  }

  final GRoot root = GRoot();
  final List<GShape> rings = <GShape>[];

  @override
  late final GStage stage = GStage(root);

  @override
  final GCanvasRenderer renderer = GCanvasRenderer();

  @override
  void update(double time, {bool animateAlpha = false}) {
    const cx = _logicalWidth * .5;
    const cy = _logicalHeight * .5;
    const pointerDx = 34.0;
    const pointerDy = -28.0;

    for (var i = 0; i < rings.length; ++i) {
      final phase = (time * .16 + i / _ringCount) % 1.0;
      final eased = phase * phase;
      final scale = .08 + eased * 6.2;
      final fade = 1 - phase;
      final drift = fade * fade;
      final ring = rings[i]
        ..x = cx + pointerDx * drift
        ..y = cy + pointerDy * drift
        ..rotation = time * (i.isEven ? .12 : -.09) + i * .045
        ..scaleX = scale
        ..scaleY = scale;
      if (animateAlpha) {
        ring.alpha = (fade * .92).clamp(0.0, 1.0).toDouble();
      } else if (ring.alpha != 1) {
        ring.alpha = 1;
      }
    }
  }

  @override
  void dispose() {
    renderer.dispose();
    stage.dispose();
  }
}

final class _BatchedRings implements _Scenario {
  _BatchedRings() {
    for (var i = 0; i < _sides; ++i) {
      final angle = -math.pi / 2 + math.pi * 2 * i / _sides;
      final radius = i.isEven ? 42.0 : 35.0;
      unitX[i] = math.cos(angle) * radius;
      unitY[i] = math.sin(angle) * radius;
    }

    root.addChild(
      GCanvasNode((context) {
        context.canvas.drawRawPoints(ui.PointMode.lines, lines, paint);
      }),
    );
    stage
      ..mount()
      ..setViewport(_logicalWidth, _logicalHeight, devicePixelRatio: _dpr);
  }

  final GRoot root = GRoot();
  final Float32List unitX = Float32List(_sides);
  final Float32List unitY = Float32List(_sides);
  final Float32List lines = Float32List(_ringCount * _sides * 4);
  final ui.Paint paint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.05
    ..strokeCap = ui.StrokeCap.round
    ..isAntiAlias = true
    ..color = const ui.Color(0xaa7cf7d4);

  @override
  late final GStage stage = GStage(root);

  @override
  final GCanvasRenderer renderer = GCanvasRenderer();

  @override
  void update(double time, {bool animateAlpha = false}) {
    const cx = _logicalWidth * .5;
    const cy = _logicalHeight * .5;
    const pointerDx = 34.0;
    const pointerDy = -28.0;

    var offset = 0;
    for (var i = 0; i < _ringCount; ++i) {
      final phase = (time * .16 + i / _ringCount) % 1.0;
      final eased = phase * phase;
      final scale = .08 + eased * 6.2;
      final fade = 1 - phase;
      final drift = fade * fade;
      final x = cx + pointerDx * drift;
      final y = cy + pointerDy * drift;
      final rotation = time * (i.isEven ? .12 : -.09) + i * .045;
      final cos = math.cos(rotation) * scale;
      final sin = math.sin(rotation) * scale;

      var firstX = 0.0;
      var firstY = 0.0;
      var previousX = 0.0;
      var previousY = 0.0;
      for (var vertex = 0; vertex < _sides; ++vertex) {
        final localX = unitX[vertex];
        final localY = unitY[vertex];
        final px = x + localX * cos - localY * sin;
        final py = y + localX * sin + localY * cos;
        if (vertex == 0) {
          firstX = previousX = px;
          firstY = previousY = py;
          continue;
        }
        offset = _write(offset, previousX, previousY, px, py);
        previousX = px;
        previousY = py;
      }
      offset = _write(offset, previousX, previousY, firstX, firstY);
    }
    stage.requestPaint();
  }

  int _write(int offset, double x1, double y1, double x2, double y2) {
    lines[offset] = x1;
    lines[offset + 1] = y1;
    lines[offset + 2] = x2;
    lines[offset + 3] = y2;
    return offset + 4;
  }

  @override
  void dispose() {
    renderer.dispose();
    stage.dispose();
  }
}
