// ignore_for_file: avoid_print

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';

const _count = 256;
double _sink = 0.0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = List<ui.Path>.generate(_count, _makePath);
  final shapes = List<GShape>.generate(_count, (i) {
    final shape = GShape();
    shape.graphics
      ..lineStyle(
        3,
        const ui.Color(0xffffffff),
        true,
        ui.StrokeCap.round,
        ui.StrokeJoin.round,
      )
      ..drawPath(paths[i]);
    return shape;
  });
  final bounds = GBounds.empty();

  print('graphx Graphics bounds benchmark');
  print(
    'Run with: flutter run -d macos --profile benchmark/graphics_bounds_benchmark.dart',
  );
  print('$_count retained cubic paths · median of 9 measured passes');
  print('');

  _report('Path.getBounds()', () {
    var total = 0.0;
    for (var i = 0; i < paths.length; ++i) {
      final rect = paths[i].getBounds();
      total += rect.width + rect.height;
    }
    _sink = total;
  });

  for (final step in const <double>[4.0, 1.0, 0.25]) {
    _report('sampled step ${step.toStringAsFixed(step < 1 ? 2 : 0)}', () {
      var total = 0.0;
      for (var i = 0; i < shapes.length; ++i) {
        shapes[i].graphics.computeApproximateBounds(bounds, sampleStep: step);
        total += bounds.width + bounds.height;
      }
      _sink = total;
    });
  }

  for (var i = 0; i < shapes.length; ++i) {
    shapes[i].dispose();
  }
  if (_sink == double.negativeInfinity) print(_sink);
  runApp(const SizedBox.shrink());
}

ui.Path _makePath(int index) {
  final wobble = (index % 17).toDouble() - 8.0;
  return ui.Path()
    ..moveTo(-82, 26)
    ..cubicTo(-42, -78 + wobble, 34, 82 - wobble, 82, -18);
}

void _report(String label, void Function() run) {
  for (var i = 0; i < 3; ++i) {
    run();
  }

  final samples = List<int>.filled(9, 0);
  for (var i = 0; i < samples.length; ++i) {
    final watch = Stopwatch()..start();
    run();
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
  }
  samples.sort();

  final us = samples[samples.length ~/ 2];
  final ms = us / 1000.0;
  final perPath = us / _count;
  print(
    '${label.padRight(20)} ${ms.toStringAsFixed(3).padLeft(9)} ms  '
    '${perPath.toStringAsFixed(3).padLeft(8)} us/path',
  );
}
