// ignore_for_file: avoid_print

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';
import 'package:graphx/graphx_extension.dart';

const _renderSamples = 9;
const _rebuildSamples = 5;
const _warmups = 3;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('GRAPHX RASTER CACHE SUITE');
  print(
    'Run profile: flutter run -d macos --profile benchmark/cache_benchmark.dart',
  );
  print('steady recording + async recapture cost');
  print('');

  for (final count in const <int>[100, 500, 2000]) {
    for (final fx in _Fx.values) {
      final scene = _buildScene(count, fx);
      _reportRender('${_label(count)} ${fx.label} live', count, scene);

      scene.target.cache
        ..enabled = true
        ..scale = 1;
      await scene.target.cache.prepare();
      _reportRender('${_label(count)} ${fx.label} cached', count, scene);
      await _reportRebuild('${_label(count)} ${fx.label} rebuild', scene);

      final bytes =
          scene.target.cache.pixelWidth * scene.target.cache.pixelHeight * 4;
      print(
        '  backing ${scene.target.cache.pixelWidth}×${scene.target.cache.pixelHeight} '
        '~${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB',
      );
      scene.dispose();
    }
    print('');
  }

  runApp(const SizedBox.shrink());
}

enum _Fx {
  none('plain'),
  blur('blur'),
  shadow('shadow');

  const _Fx(this.label);
  final String label;
}

_BenchScene _buildScene(int count, _Fx fx) {
  final root = GRoot();
  final target = root.addChild(GNode(name: 'cached'));
  late _BenchLeaf mutable;
  for (var i = 0; i < count; ++i) {
    final leaf = target.addChild(_BenchLeaf(i));
    if (i == count ~/ 2) mutable = leaf;
  }

  target.filters = switch (fx) {
    _Fx.none => const <GFilter>[],
    _Fx.blur => <GFilter>[GBlurFilter(blurX: 2.5, blurY: 2.5)],
    _Fx.shadow => <GFilter>[
      GDropShadowFilter(
        offsetX: 7,
        offsetY: 8,
        blurX: 4,
        blurY: 4,
        color: const ui.Color(0x88000000),
      ),
    ],
  };

  final stage = GStage(root)
    ..mount()
    ..setViewport(2048, 2048, devicePixelRatio: 1);
  return _BenchScene(root, stage, target, mutable, GCanvasRenderer());
}

final class _BenchScene {
  _BenchScene(this.root, this.stage, this.target, this.mutable, this.renderer);

  final GRoot root;
  final GStage stage;
  final GNode target;
  final _BenchLeaf mutable;
  final GCanvasRenderer renderer;
  bool mutation = false;

  void mutate() {
    mutation = !mutation;
    mutable.alpha = mutation ? .94 : 1.0;
  }

  void dispose() {
    renderer.dispose();
    stage.dispose();
  }
}

final class _BenchLeaf extends GNode {
  _BenchLeaf(int index) : _x = (index % 80) * 12.0, _y = (index ~/ 80) * 12.0 {
    setPaintSelf(true);
  }

  static final ui.Paint _paint = ui.Paint()..color = const ui.Color(0xff59d9d0);
  final double _x;
  final double _y;

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(_x, _y, 7, 7);

  @override
  void paintSelf(GRenderContext context) {
    final previous = _paint.color;
    _paint.color = previous.withValues(alpha: context.alpha);
    context.canvas.drawRect(ui.Rect.fromLTWH(_x, _y, 7, 7), _paint);
    _paint.color = previous;
  }
}

void _reportRender(String label, int count, _BenchScene scene) {
  for (var i = 0; i < _warmups; ++i) {
    _record(scene);
  }
  final samples = List<int>.filled(_renderSamples, 0);
  for (var i = 0; i < samples.length; ++i) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final watch = Stopwatch()..start();
    scene.renderer.render(canvas, scene.stage);
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
    recorder.endRecording().dispose();
  }
  _printSamples(label, samples, nsPer: count);
}

Future<void> _reportRebuild(String label, _BenchScene scene) async {
  for (var i = 0; i < 2; ++i) {
    scene.mutate();
    await scene.target.cache.prepare();
  }
  final samples = List<int>.filled(_rebuildSamples, 0);
  for (var i = 0; i < samples.length; ++i) {
    scene.mutate();
    final watch = Stopwatch()..start();
    await scene.target.cache.prepare();
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
  }
  _printSamples(label, samples);
}

void _record(_BenchScene scene) {
  final recorder = ui.PictureRecorder();
  scene.renderer.render(ui.Canvas(recorder), scene.stage);
  recorder.endRecording().dispose();
}

void _printSamples(String label, List<int> samples, {int? nsPer}) {
  samples.sort();
  final p50 = samples[samples.length ~/ 2];
  final p95 = samples.last;
  final per = nsPer == null
      ? ''
      : '  ${(p50 * 1000 / nsPer).toStringAsFixed(1)} ns/leaf';
  print(
    '${label.padRight(24)} '
    'p50 ${(p50 / 1000).toStringAsFixed(3).padLeft(8)} ms  '
    'p95 ${(p95 / 1000).toStringAsFixed(3).padLeft(8)} ms$per',
  );
}

String _label(int count) => count >= 1000 ? '${count ~/ 1000}K' : '$count';
