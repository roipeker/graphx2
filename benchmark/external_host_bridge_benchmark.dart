// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';

const _width = 1280.0;
const _height = 720.0;
const _warmups = 80;
const _syncSamples = 400;
const _renderWarmups = 20;
const _renderSamples = 120;
const _counts = <int>[100, 500, 1000, 5000];

final ui.Paint _bodyPaint = ui.Paint()
  ..isAntiAlias = false
  ..color = const ui.Color(0xffd7e3ff);
final ui.Paint _accentPaint = ui.Paint()
  ..isAntiAlias = false
  ..color = const ui.Color(0xff6be6c1);

void _paintBody(GRenderContext context) {
  context.canvas.drawRect(const ui.Rect.fromLTWH(-3, -2, 6, 4), _bodyPaint);
}

void _paintAccent(GRenderContext context) {
  context.canvas.drawRect(const ui.Rect.fromLTWH(-1, -5, 2, 3), _accentPaint);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('SATECHI EXTERNAL HOST BRIDGE SUITE');
  print('isolates host→GNode transform sync and retained render cost');
  print('all values are p50 / p95; lower is better');
  print('direct Canvas is a lower-bound custom-render baseline, not Flame FCS');
  print('');

  for (final count in _counts) {
    await _run(count);
  }

  print('SATECHI_BENCHMARK_COMPLETE');
  exit(0);
}

Future<void> _run(int count) async {
  final states = _HostStates(count)..advance(0);
  final simple = _SimpleGraphXVisuals(count);
  final rich = _RichGraphXVisuals(count);

  // Warm mutation/invalidation paths before sampling.
  for (var i = 0; i < _warmups; ++i) {
    states.advance(i + 1);
    simple.sync(states);
    rich.sync(states);
  }

  final changedSimple = <int>[];
  final unchangedSimple = <int>[];
  final changedRich = <int>[];
  final unchangedRich = <int>[];

  for (var i = 0; i < _syncSamples; ++i) {
    states.advance(i + 1000);
    changedSimple.add(_micros(() => simple.sync(states)));
    unchangedSimple.add(_micros(() => simple.sync(states)));

    states.advance(i + 2000);
    changedRich.add(_micros(() => rich.sync(states)));
    unchangedRich.add(_micros(() => rich.sync(states)));
  }

  for (var i = 0; i < _renderWarmups; ++i) {
    states.advance(i + 3000);
    simple.sync(states);
    rich.sync(states);
    _recordDirect(states).dispose();
    _recordGraphX(simple.renderer, simple.stage).dispose();
    _recordGraphX(rich.renderer, rich.stage).dispose();
  }

  final directRender = <int>[];
  final simpleRender = <int>[];
  final richRender = <int>[];

  for (var i = 0; i < _renderSamples; ++i) {
    states.advance(i + 4000);
    simple.sync(states);
    rich.sync(states);

    directRender.add(_micros(() => _recordDirect(states).dispose()));
    simpleRender.add(
      _micros(() => _recordGraphX(simple.renderer, simple.stage).dispose()),
    );
    richRender.add(
      _micros(() => _recordGraphX(rich.renderer, rich.stage).dispose()),
    );
  }

  print('entities: $count');
  _print('sync simple changed', changedSimple, count);
  _print('sync simple unchanged', unchangedSimple, count);
  _print('sync rich-root changed', changedRich, count);
  _print('sync rich-root unchanged', unchangedRich, count);
  _print('render direct Canvas', directRender, count);
  _print('render GraphX simple', simpleRender, count);
  _print('render GraphX rich(5n)', richRender, count);
  print('');

  simple.dispose();
  rich.dispose();
}

int _micros(void Function() body) {
  final watch = Stopwatch()..start();
  body();
  watch.stop();
  return watch.elapsedMicroseconds;
}

void _print(String label, List<int> samples, int count) {
  final stats = _stats(samples);
  final perEntityNs = stats.$1 * 1000 / count;
  print(
    '  ${label.padRight(25)} '
    '${_ms(stats.$1)} / ${_ms(stats.$2)} ms  '
    'p50 ${perEntityNs.toStringAsFixed(1)} ns/entity',
  );
}

(int, int) _stats(List<int> values) {
  values.sort();
  final p50 = values[values.length ~/ 2];
  final p95 = values[(values.length * .95).floor().clamp(0, values.length - 1)];
  return (p50, p95);
}

String _ms(int microseconds) => (microseconds / 1000).toStringAsFixed(3);

ui.Picture _recordDirect(_HostStates states) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var i = 0; i < states.count; ++i) {
    canvas.save();
    canvas.translate(states.x[i], states.y[i]);
    canvas.rotate(states.rotation[i]);
    canvas.drawRect(const ui.Rect.fromLTWH(-3, -2, 6, 4), _bodyPaint);
    canvas.restore();
  }
  return recorder.endRecording();
}

ui.Picture _recordGraphX(GCanvasRenderer renderer, GStage stage) {
  final recorder = ui.PictureRecorder();
  renderer.render(ui.Canvas(recorder), stage);
  return recorder.endRecording();
}

final class _HostStates {
  _HostStates(this.count)
    : x = Float64List(count),
      y = Float64List(count),
      rotation = Float64List(count);

  final int count;
  final Float64List x;
  final Float64List y;
  final Float64List rotation;

  void advance(int frame) {
    final t = frame / 60.0;
    const columns = 100;
    for (var i = 0; i < count; ++i) {
      final column = i % columns;
      final row = i ~/ columns;
      final phase = t * .7 + i * .013;
      x[i] = 8 + column * 12 + math.sin(phase) * 2.5;
      y[i] = 8 + (row % 58) * 12 + math.cos(phase * .83) * 2.0;
      rotation[i] = math.sin(phase * .37) * .35;
    }
  }
}

abstract interface class _GraphXVisuals {
  GStage get stage;
  GCanvasRenderer get renderer;
  void sync(_HostStates states);
  void dispose();
}

final class _SimpleGraphXVisuals implements _GraphXVisuals {
  _SimpleGraphXVisuals(int count) {
    for (var i = 0; i < count; ++i) {
      nodes.add(root.addChild(GCanvasNode(_paintBody)));
    }
    stage
      ..mount()
      ..setViewport(_width, _height);
  }

  final GRoot root = GRoot();
  final List<GCanvasNode> nodes = <GCanvasNode>[];

  @override
  late final GStage stage = GStage(root);

  @override
  final GCanvasRenderer renderer = GCanvasRenderer();

  @override
  void sync(_HostStates states) {
    for (var i = 0; i < nodes.length; ++i) {
      final node = nodes[i];
      final x = states.x[i];
      final y = states.y[i];
      final rotation = states.rotation[i];
      if (node.x != x) node.x = x;
      if (node.y != y) node.y = y;
      if (node.rotation != rotation) node.rotation = rotation;
    }
  }

  @override
  void dispose() {
    renderer.dispose();
    stage.dispose();
  }
}

final class _RichGraphXVisuals implements _GraphXVisuals {
  _RichGraphXVisuals(int count) {
    for (var i = 0; i < count; ++i) {
      final group = root.addChild(GNode('visual-$i'));
      group.addChild(GCanvasNode(_paintBody));
      group.addChild(GCanvasNode(_paintAccent)..x = 4);
      group.addChild(GCanvasNode(_paintAccent)..x = -4);
      group.addChild(GCanvasNode(_paintAccent)..y = 4);
      roots.add(group);
    }
    stage
      ..mount()
      ..setViewport(_width, _height);
  }

  final GRoot root = GRoot();
  final List<GNode> roots = <GNode>[];

  @override
  late final GStage stage = GStage(root);

  @override
  final GCanvasRenderer renderer = GCanvasRenderer();

  @override
  void sync(_HostStates states) {
    for (var i = 0; i < roots.length; ++i) {
      final node = roots[i];
      final x = states.x[i];
      final y = states.y[i];
      final rotation = states.rotation[i];
      if (node.x != x) node.x = x;
      if (node.y != y) node.y = y;
      if (node.rotation != rotation) node.rotation = rotation;
    }
  }

  @override
  void dispose() {
    renderer.dispose();
    stage.dispose();
  }
}
