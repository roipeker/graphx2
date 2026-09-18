// ignore_for_file: avoid_print

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';

const _samples = 9;
const _warmups = 3;
double _sink = 0.0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  print('SATECHI FILTER SUITE');
  print(
    'Run profile: flutter run -d macos --profile benchmark/filter_benchmark.dart',
  );
  print('median of $_samples measured passes · $_warmups warmups');
  print('');

  _boundsSuite();
  _renderSuite();
  _mutationSuite();
  _layerPressureSuite();

  if (_sink == double.negativeInfinity) print(_sink);
  runApp(const SizedBox.shrink());
}

void _boundsSuite() {
  print('EFFECT BOUNDS');
  for (final count in const <int>[100, 1000, 10000]) {
    final flat = _buildScene(count: count, groups: 1, filteredGroups: false);
    final nested = _buildScene(
      count: count,
      groups: _groupCountFor(count),
      filteredGroups: true,
    );
    final out = GBounds.empty();

    // Warm the canonical local-bounds cache first. getEffectBounds() remains an
    // explicit tooling/query walk and must not mutate that cache.
    flat.root.localBounds;
    nested.root.localBounds;

    _report('${_countLabel(count)} local cached', count, () {
      final bounds = flat.root.localBounds;
      _sink += bounds.width + bounds.height;
    });
    _report('${_countLabel(count)} effect flat', count, () {
      flat.root.getEffectBounds(out);
      _sink += out.width + out.height;
    });
    _report('${_countLabel(count)} effect nested', count, () {
      nested.root.getEffectBounds(out);
      _sink += out.width + out.height;
    });

    flat.dispose();
    nested.dispose();
  }
  print('');
}

void _renderSuite() {
  print('RENDER RECORDING');
  for (final count in const <int>[360, 1000, 10000]) {
    final plain = _buildScene(count: count, groups: 1, filteredGroups: false);
    final linear = _buildScene(
      count: count,
      groups: 1,
      filteredGroups: false,
      outerFilters: [_blur(), _matrix()],
    );
    final nestedLinear = _buildScene(
      count: count,
      groups: _groupCountFor(count),
      filteredGroups: true,
      outerFilters: [_matrix()],
    );

    _reportRender('${_countLabel(count)} plain', count, plain);
    _reportRender('${_countLabel(count)} blur+matrix', count, linear);
    _reportRender('${_countLabel(count)} nested linear', count, nestedLinear);

    plain.dispose();
    linear.dispose();
    nestedLinear.dispose();
  }
  print('');
}

void _mutationSuite() {
  print('FILTER MUTATION / NATIVE CACHE INVALIDATION');
  const count = 360;
  final blur = _blur();
  final scene = _buildScene(
    count: count,
    groups: 1,
    filteredGroups: false,
    outerFilters: [blur, _matrix()],
  );

  _reportRender('stable blur+matrix', count, scene);
  var phase = 0;
  _reportRender(
    'animated blur+matrix',
    count,
    scene,
    beforeRender: () {
      phase++;
      final sigma = 1.0 + (phase % 12) * .35;
      blur.setBlur(sigma, sigma * .75);
    },
  );
  scene.dispose();
  print('');
}

void _layerPressureSuite() {
  print('LAYER PRESSURE · SAME 360 LEAVES / SAME PIXEL POSITIONS');
  const count = 360;

  final baseline = _buildScene(
    count: count,
    groups: 1,
    filteredGroups: false,
    outerFilters: [_blur(), _matrix()],
  );
  _reportRender('1 layer baseline', count, baseline);
  baseline.dispose();

  // All variants contain the same 360 rectangles at the same coordinates.
  // Only grouping/filter hierarchy changes. With an outer shadow→matrix the
  // current Canvas path is: 3 outer layers + two replays of each group blur.
  for (final groups in const <int>[1, 3, 6, 12, 30]) {
    final scene = _buildScene(
      count: count,
      groups: groups,
      filteredGroups: true,
      outerFilters: [_shadow(), _matrix()],
    );
    final expectedLayers = 3 + groups * 2;
    _reportRender('$expectedLayers layers / $groups groups', count, scene);
    scene.dispose();
  }
  print('');
}

_BenchScene _buildScene({
  required int count,
  required int groups,
  required bool filteredGroups,
  List<GFilter>? outerFilters,
}) {
  assert(count > 0 && groups > 0 && count % groups == 0);
  final root = GRoot();
  final outer = root.addChild(GNode('bench-outer'));
  if (outerFilters != null) outer.filters = outerFilters;

  final leavesPerGroup = count ~/ groups;
  for (var g = 0; g < groups; ++g) {
    final group = outer.addChild(GNode('group-$g'));
    if (filteredGroups) group.filters = [GBlurFilter(blurX: 1.4, blurY: 1.4)];
    final start = g * leavesPerGroup;
    final end = start + leavesPerGroup;
    for (var i = start; i < end; ++i) {
      // Absolute coordinates inside zero-transform groups guarantee every
      // hierarchy variant paints identical leaf geometry.
      group.addChild(_BenchLeaf(i));
    }
  }

  final stage = GStage(root)..mount();
  stage.setViewport(2048, 2048);
  return _BenchScene(root, stage, GCanvasRenderer());
}

final class _BenchScene {
  _BenchScene(this.root, this.stage, this.renderer);

  final GRoot root;
  final GStage stage;
  final GCanvasRenderer renderer;

  void dispose() {
    renderer.dispose();
    stage.dispose();
  }
}

final class _BenchLeaf extends GNode {
  _BenchLeaf(int index)
    : _x = (index % 100) * 15.0,
      _y = (index ~/ 100) * 15.0 {
    setPaintSelf(true);
  }

  static final ui.Paint _paint = ui.Paint()..color = const ui.Color(0xffffffff);
  final double _x;
  final double _y;

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(_x, _y, 9, 9);

  @override
  void paintSelf(GRenderContext context) {
    context.canvas.drawRect(ui.Rect.fromLTWH(_x, _y, 9, 9), _paint);
  }
}

GBlurFilter _blur() => GBlurFilter(blurX: 1.8, blurY: 1.8);

GDropShadowFilter _shadow() => GDropShadowFilter(
  offsetX: 8,
  offsetY: 9,
  blurX: 3,
  blurY: 3,
  color: const ui.Color(0x88000000),
);

GColorMatrixFilter _matrix() => GColorMatrixFilter(const <double>[
  1.04,
  0,
  0,
  0,
  4,
  0,
  .96,
  0,
  0,
  0,
  0,
  0,
  1.08,
  0,
  2,
  0,
  0,
  0,
  1,
  0,
]);

int _groupCountFor(int count) {
  if (count >= 10000) return 20;
  if (count >= 1000) return 10;
  if (count == 360) return 6;
  return 5;
}

String _countLabel(int count) => count >= 1000 ? '${count ~/ 1000}K' : '$count';

void _reportRender(
  String label,
  int count,
  _BenchScene scene, {
  void Function()? beforeRender,
}) {
  // Prime retained native filter caches before timing.
  for (var i = 0; i < _warmups; ++i) {
    beforeRender?.call();
    _record(scene);
  }

  final samples = List<int>.filled(_samples, 0);
  for (var i = 0; i < samples.length; ++i) {
    beforeRender?.call();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final watch = Stopwatch()..start();
    scene.renderer.render(canvas, scene.stage);
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
    recorder.endRecording().dispose();
  }
  _printSamples(label, count, samples);
}

void _record(_BenchScene scene) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  scene.renderer.render(canvas, scene.stage);
  recorder.endRecording().dispose();
}

void _report(String label, int count, void Function() run) {
  for (var i = 0; i < _warmups; ++i) {
    run();
  }
  final samples = List<int>.filled(_samples, 0);
  for (var i = 0; i < samples.length; ++i) {
    final watch = Stopwatch()..start();
    run();
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
  }
  _printSamples(label, count, samples);
}

void _printSamples(String label, int count, List<int> samples) {
  samples.sort();
  final p50 = samples[samples.length ~/ 2];
  final p95 = samples.last;
  print(
    '${label.padRight(27)} '
    'p50 ${(p50 / 1000).toStringAsFixed(3).padLeft(8)} ms  '
    'p95 ${(p95 / 1000).toStringAsFixed(3).padLeft(8)} ms  '
    '${(p50 * 1000 / count).toStringAsFixed(1).padLeft(7)} ns/leaf',
  );
}
