// ignore_for_file: avoid_print

import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';

const _count = 256;
const _passes = 9;
double _sink = 0.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final source = List<ui.Path>.generate(_count, _curve);
  final motif = ui.Path()
    ..moveTo(-4, -5)
    ..lineTo(7, 0)
    ..lineTo(-4, 5);
  final linePattern = GLinePattern(motif, advance: 18);
  final filledPattern = GLinePattern(
    ui.Path()
      ..moveTo(-5, -4)
      ..lineTo(6, 0)
      ..lineTo(-5, 4)
      ..close(),
    advance: 18,
    filled: true,
  );

  final solid = _shapes(source, (g, path) {
    g
      ..lineStyle(2, const ui.Color(0xffffffff), true, ui.StrokeCap.round)
      ..drawPath(path);
  });
  final dashed = _shapes(source, (g, path) {
    g
      ..lineStyle(2, const ui.Color(0xffffffff), true, ui.StrokeCap.round)
      ..lineDash(const [10, 6], phase: 3)
      ..drawPath(path);
  });
  final patterned = _shapes(source, (g, path) {
    g
      ..lineStyle(2, const ui.Color(0xffffffff), true, ui.StrokeCap.round)
      ..linePattern(linePattern, phase: 4)
      ..drawPath(path);
  });
  final filled = _shapes(source, (g, path) {
    g
      ..lineStyle(2, const ui.Color(0xffffffff))
      ..linePattern(filledPattern, phase: 4)
      ..drawPath(path);
  });

  // Prime derived geometry and PathMetric snapshots before steady-state tests.
  _paintAll(solid);
  _paintAll(dashed);
  _paintAll(patterned);
  _paintAll(filled);

  print('graphx Graphics line decoration benchmark');
  print(
    'Run with: flutter run -d macos --profile benchmark/graphics_line_pattern_benchmark.dart',
  );
  print('$_count retained cubic paths · median of $_passes measured passes');
  print('');

  _report('solid retained paint', () => _paintAll(solid));
  _report('dash retained paint', () => _paintAll(dashed));
  _report('pattern retained paint', () => _paintAll(patterned));
  _report('filled retained paint', () => _paintAll(filled));

  _report('pattern phase + paint', () {
    linePattern.phase += 1.0;
    _paintAll(patterned);
  });
  _report('filled phase + paint', () {
    filledPattern.phase += 1.0;
    _paintAll(filled);
  });

  _report('dash rebuild + paint', () {
    for (var i = 0; i < dashed.length; ++i) {
      final path = source[i];
      dashed[i].graphics.redraw((g) {
        g
          ..lineStyle(2, const ui.Color(0xffffffff), true, ui.StrokeCap.round)
          ..lineDash(const [10, 6], phase: 3)
          ..drawPath(path);
      });
    }
    _paintAll(dashed);
  });

  _report('pattern rebuild + paint', () {
    for (var i = 0; i < patterned.length; ++i) {
      final path = source[i];
      patterned[i].graphics.redraw((g) {
        g
          ..lineStyle(2, const ui.Color(0xffffffff), true, ui.StrokeCap.round)
          ..linePattern(linePattern, phase: 4)
          ..drawPath(path);
      });
    }
    _paintAll(patterned);
  });

  _report('filled rebuild + paint', () {
    for (var i = 0; i < filled.length; ++i) {
      final path = source[i];
      filled[i].graphics.redraw((g) {
        g
          ..lineStyle(2, const ui.Color(0xffffffff))
          ..linePattern(filledPattern, phase: 4)
          ..drawPath(path);
      });
    }
    _paintAll(filled);
  });

  for (final shape in [...solid, ...dashed, ...patterned, ...filled]) {
    shape.dispose();
  }
  if (_sink == double.negativeInfinity) print(_sink);
  await io.stdout.flush();
  io.exit(0);
}

List<GShape> _shapes(
  List<ui.Path> paths,
  void Function(GGraphics graphics, ui.Path path) draw,
) => List<GShape>.generate(paths.length, (i) {
  final shape = GShape();
  draw(shape.graphics, paths[i]);
  return shape;
});

ui.Path _curve(int index) {
  final wobble = (index % 19).toDouble() - 9.0;
  return ui.Path()
    ..moveTo(-90, 24)
    ..cubicTo(-52, -72 + wobble, 36, 78 - wobble, 90, -18);
}

void _paintAll(List<GShape> shapes) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  var total = 0.0;
  for (var i = 0; i < shapes.length; ++i) {
    final graphics = shapes[i].graphics;
    graphics.paint(canvas, 1);
    total += graphics.batchCount;
  }
  recorder.endRecording().dispose();
  _sink = total;
}

void _report(String label, void Function() run) {
  for (var i = 0; i < 3; ++i) {
    run();
  }

  final samples = List<int>.filled(_passes, 0);
  for (var i = 0; i < samples.length; ++i) {
    final watch = Stopwatch()..start();
    run();
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
  }
  samples.sort();

  final us = samples[samples.length ~/ 2];
  print(
    '${label.padRight(24)} ${(us / 1000).toStringAsFixed(3).padLeft(9)} ms  '
    '${(us / _count).toStringAsFixed(3).padLeft(8)} us/path',
  );
}
