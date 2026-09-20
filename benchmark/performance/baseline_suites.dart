// Copyright (c) 2026 GraphX by roipeker.

// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:graphx/graphx.dart';
import 'package:graphx/graphx_extension.dart';

import 'benchmark_harness.dart';

const _suite = 'rendering-performance-baseline';
const _counts = <int>[100, 1000, 10000];

Future<void> runGraphXPerformanceBaseline(GraphXBenchmarkHarness harness) async {
  harness.printHeader(suite: _suite);
  _runStaticSceneSuite(harness);
  _runTransformSuite(harness);
  _runGraphicsSuite(harness);
  await _runCacheSuite(harness);
  _runSceneMutationSuite(harness);
  _runHitTestingSuite(harness);
  await _runImageSuite(harness);
  print('');
  print('GRAPHX_BENCHMARK_COMPLETE');
}

void _runStaticSceneSuite(GraphXBenchmarkHarness harness) {
  print('STATIC RETAINED SCENE');
  for (final count in _counts) {
    final scene = _buildFlatScene(count);
    _measureRender(
      harness,
      workload: 'static retained $count',
      scene: scene,
      count: count,
      configuration: const <String, Object?>{'layout': 'flat', 'paint': 'rect'},
    );
    scene.dispose();
  }
  print('');
}

void _runTransformSuite(GraphXBenchmarkHarness harness) {
  print('TRANSFORM INVALIDATION + LAZY RESOLUTION');
  for (final count in _counts) {
    final scene = _buildTransformScene(count);
    var phase = false;
    void mutateLeaves() {
      phase = !phase;
      final delta = phase ? .25 : -.25;
      final scale = phase ? 1.01 : .99;
      for (final node in scene.nodes) {
        node.x += delta;
        node.y -= delta;
        node.rotation += delta * .01;
        node.scaleX = scale;
        node.scaleY = scale;
      }
    }

    harness.measureSync(
      suite: _suite,
      workload: 'all transforms $count',
      metric: 'mutation',
      count: count,
      operations: count,
      body: mutateLeaves,
      configuration: const <String, Object?>{'properties_per_node': 5},
    );
    _measureRender(
      harness,
      workload: 'all transforms $count',
      scene: scene,
      count: count,
      beforeRender: mutateLeaves,
      configuration: const <String, Object?>{'properties_per_node': 5},
    );

    var parentPhase = false;
    void mutateParents() {
      parentPhase = !parentPhase;
      final delta = parentPhase ? .5 : -.5;
      for (final group in scene.groups) {
        group.x += delta;
        group.rotation += delta * .005;
      }
    }

    _measureRender(
      harness,
      workload: 'parent transforms $count',
      scene: scene,
      count: count,
      beforeRender: mutateParents,
      configuration: <String, Object?>{'parent_count': scene.groups.length},
    );
    scene.dispose();
  }
  print('');
}

void _runGraphicsSuite(GraphXBenchmarkHarness harness) {
  print('GRAPHICS RETENTION + REBUILD');
  for (final count in _counts) {
    final scene = _buildGraphicsScene(count, complex: false);
    _measureRender(
      harness,
      workload: 'graphics retained $count',
      scene: scene,
      count: count,
      configuration: const <String, Object?>{'geometry': 'small_rect'},
    );

    var phase = false;
    void rebuild() {
      phase = !phase;
      final inset = phase ? .5 : 0.0;
      for (final shape in scene.shapes) {
        final graphics = shape.graphics;
        graphics.clear();
        graphics.beginFill(const ui.Color(0xff59d9d0));
        graphics.drawRect(inset, inset, 8 - inset, 8 - inset);
        graphics.endFill();
      }
    }

    harness.measureSync(
      suite: _suite,
      workload: 'graphics clear+redraw $count',
      metric: 'mutation',
      count: count,
      operations: count,
      body: rebuild,
      configuration: const <String, Object?>{'geometry': 'small_rect'},
    );
    _measureRender(
      harness,
      workload: 'graphics clear+redraw $count',
      scene: scene,
      count: count,
      beforeRender: rebuild,
      configuration: const <String, Object?>{'geometry': 'small_rect'},
    );
    scene.dispose();
  }

  for (final count in const <int>[64, 256]) {
    final scene = _buildGraphicsScene(count, complex: true);
    _measureRender(
      harness,
      workload: 'graphics complex $count',
      scene: scene,
      count: count,
      configuration: const <String, Object?>{'geometry': '48_segment_path'},
    );

    var phase = false;
    void rebuild() {
      phase = !phase;
      final paths = scene.paths;
      for (var i = 0; i < scene.shapes.length; ++i) {
        final graphics = scene.shapes[i].graphics;
        graphics.clear();
        graphics.lineStyle(1.5, phase ? const ui.Color(0xffa88cff) : const ui.Color(0xff59d9d0));
        graphics.drawPath(paths[i]);
      }
    }

    harness.measureSync(
      suite: _suite,
      workload: 'complex clear+redraw $count',
      metric: 'mutation',
      count: count,
      operations: count,
      body: rebuild,
      configuration: const <String, Object?>{'geometry': '48_segment_path'},
    );
    scene.dispose();
  }
  print('');
}

Future<void> _runCacheSuite(GraphXBenchmarkHarness harness) async {
  print('RASTER CACHE');
  for (final count in const <int>[100, 1000, 5000]) {
    final scene = _buildCacheScene(count);
    _measureRender(
      harness,
      workload: 'cache live $count',
      scene: scene,
      count: count,
      configuration: const <String, Object?>{'cache': 'disabled'},
    );

    final cache = scene.cacheTarget!.cache;
    cache.enabled = true;
    cache.scale = 1;
    await cache.prepare();

    _measureRender(
      harness,
      workload: 'cache warm $count',
      scene: scene,
      count: count,
      configuration: <String, Object?>{
        'cache': 'ready',
        'pixel_width': cache.pixelWidth,
        'pixel_height': cache.pixelHeight,
      },
    );

    await harness.measureAsync(
      suite: _suite,
      workload: 'cache cold build $count',
      metric: 'rasterize',
      count: count,
      operations: count,
      beforeSample: cache.clear,
      body: cache.prepare,
      configuration: const <String, Object?>{'cache': 'clear_then_prepare'},
    );

    var phase = false;
    await harness.measureAsync(
      suite: _suite,
      workload: 'cache content invalidation $count',
      metric: 'rebuild',
      count: count,
      operations: count,
      beforeSample: () {
        phase = !phase;
        scene.mutableLeaf!.alpha = phase ? .92 : 1.0;
      },
      body: cache.prepare,
      configuration: const <String, Object?>{'mutation': 'leaf_alpha'},
    );

    var movePhase = false;
    _measureRender(
      harness,
      workload: 'cache move target $count',
      scene: scene,
      count: count,
      beforeRender: () {
        movePhase = !movePhase;
        scene.cacheTarget!.x += movePhase ? .5 : -.5;
      },
      configuration: const <String, Object?>{'mutation': 'cached_node_transform'},
    );

    var reparentPhase = false;
    await harness.measureAsync(
      suite: _suite,
      workload: 'cache reparent $count',
      metric: 'rebuild',
      count: count,
      operations: count,
      beforeSample: () {
        reparentPhase = !reparentPhase;
        final parent = reparentPhase ? scene.cacheLeft! : scene.cacheRight!;
        parent.addChild(scene.mutableLeaf!);
      },
      body: cache.prepare,
      configuration: const <String, Object?>{'mutation': 'same_stage_reparent'},
    );
    scene.dispose();
  }
  print('');
}

void _runSceneMutationSuite(GraphXBenchmarkHarness harness) {
  print('SCENE MUTATION');
  for (final count in _counts) {
    final scene = _buildFlatScene(count);
    var phase = false;
    harness.measureSync(
      suite: _suite,
      workload: 'visibility $count',
      metric: 'mutation',
      count: count,
      operations: count,
      body: () {
        phase = !phase;
        for (final node in scene.nodes) {
          node.visible = phase;
        }
      },
    );
    harness.measureSync(
      suite: _suite,
      workload: 'alpha $count',
      metric: 'mutation',
      count: count,
      operations: count,
      body: () {
        phase = !phase;
        final alpha = phase ? .85 : 1.0;
        for (final node in scene.nodes) {
          node.alpha = alpha;
        }
      },
    );
    harness.measureSync(
      suite: _suite,
      workload: 'bounds invalidation $count',
      metric: 'mutation',
      count: count,
      operations: count,
      body: () {
        phase = !phase;
        final extent = phase ? 8.25 : 8.0;
        for (final node in scene.nodes) {
          if (node is _BenchLeaf) node.resize(extent, extent);
        }
      },
    );
    scene.dispose();
  }

  final root = GRoot();
  final stage = GStage(root);
  stage.mount();
  stage.setViewport(1280, 720);
  final pool = List<GNode>.generate(128, (_) => GNode(), growable: false);
  harness.measureSync(
    suite: _suite,
    workload: 'add+remove attached nodes',
    metric: 'mutation',
    count: pool.length,
    operations: pool.length * 2,
    body: () {
      for (final node in pool) {
        root.addChild(node);
      }
      for (final node in pool) {
        root.removeChild(node);
      }
    },
    configuration: const <String, Object?>{'allocation': 'preallocated_nodes'},
  );

  final left = root.addChild(GNode(name: 'left'));
  final right = root.addChild(GNode(name: 'right'));
  for (final node in pool) {
    left.addChild(node);
  }
  var toRight = true;
  harness.measureSync(
    suite: _suite,
    workload: 'same-stage reparent',
    metric: 'mutation',
    count: pool.length,
    operations: pool.length,
    body: () {
      final target = toRight ? right : left;
      toRight = !toRight;
      for (final node in pool) {
        target.addChild(node);
      }
    },
  );
  stage.dispose();
  print('');
}

void _runHitTestingSuite(GraphXBenchmarkHarness harness) {
  print('HIT TESTING + POINTER ROUTING');
  for (final count in _counts) {
    final absolute = _buildHitScene(count, transformed: false);
    harness.measureSync(
      suite: _suite,
      workload: 'hit shallow $count',
      metric: 'hitTest',
      count: count,
      operations: count,
      body: () {
        final hit = absolute.stage.hitTest(1, 1);
        if (hit == null) throw StateError('benchmark hit unexpectedly missed');
      },
      configuration: const <String, Object?>{'transformed': false, 'target': 'first_child'},
    );
    absolute.dispose();

    final transformed = _buildHitScene(count, transformed: true);
    harness.measureSync(
      suite: _suite,
      workload: 'hit transformed $count',
      metric: 'hitTest',
      count: count,
      operations: count,
      body: () {
        final hit = transformed.stage.hitTest(1, 1);
        if (hit == null) throw StateError('benchmark hit unexpectedly missed');
      },
      configuration: const <String, Object?>{'transformed': true, 'target': 'first_child'},
    );
    transformed.dispose();

    final pointer = _buildPointerScene(count, disabledSubtree: false);
    _measurePointerRouting(harness, pointer, count, disabledSubtree: false);
    pointer.dispose();

    final disabled = _buildPointerScene(count, disabledSubtree: true);
    _measurePointerRouting(harness, disabled, count, disabledSubtree: true);
    disabled.dispose();
  }

  for (final depth in const <int>[100, 500, 1000]) {
    final scene = _buildDeepHitScene(depth);
    harness.measureSync(
      suite: _suite,
      workload: 'hit deep $depth',
      metric: 'hitTest',
      count: depth,
      operations: depth,
      body: () {
        final hit = scene.stage.hitTest(1, 1);
        if (hit == null) throw StateError('deep benchmark hit unexpectedly missed');
      },
      configuration: const <String, Object?>{'shape': 'single_child_chain'},
    );
    scene.dispose();
  }
  print('');
}

Future<void> _runImageSuite(GraphXBenchmarkHarness harness) async {
  print('IMAGES + BATCHING');
  final pictureRecorder = ui.PictureRecorder();
  final pictureCanvas = ui.Canvas(pictureRecorder);
  final paint = ui.Paint();
  paint.color = const ui.Color(0xffffffff);
  pictureCanvas.drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), paint);
  final picture = pictureRecorder.endRecording();
  final image = await picture.toImage(8, 8);
  picture.dispose();
  final texture = GTexture(image);

  try {
    for (final count in _counts) {
      final independent = _buildImageScene(texture, count);
      final batched = _buildImageBatchScene(texture, count);

      _measureRender(
        harness,
        workload: 'images independent $count',
        scene: independent,
        count: count,
        configuration: const <String, Object?>{'strategy': 'GImage_nodes'},
      );
      _measureRender(
        harness,
        workload: 'images batched $count',
        scene: batched,
        count: count,
        configuration: const <String, Object?>{'strategy': 'GImageBatch'},
      );

      var phase = false;
      harness.measureSync(
        suite: _suite,
        workload: 'images transform $count',
        metric: 'mutation',
        count: count,
        operations: count,
        body: () {
          phase = !phase;
          final delta = phase ? .25 : -.25;
          final scale = phase ? 1.01 : .99;
          for (final node in independent.nodes) {
            node.x += delta;
            node.y -= delta;
            node.rotation += delta * .01;
            node.scaleX = scale;
            node.scaleY = scale;
          }
        },
        configuration: const <String, Object?>{'strategy': 'GImage_nodes'},
      );
      harness.measureSync(
        suite: _suite,
        workload: 'batch transform $count',
        metric: 'mutation',
        count: count,
        operations: count,
        body: () {
          phase = !phase;
          final delta = phase ? .25 : -.25;
          final scale = phase ? 1.01 : .99;
          for (final instance in batched.imageInstances) {
            instance.setTransform(
              x: instance.x + delta,
              y: instance.y - delta,
              rotation: instance.rotation + delta * .01,
              scale: scale,
            );
          }
        },
        configuration: const <String, Object?>{'strategy': 'GImageBatch'},
      );

      harness.measureSync(
        suite: _suite,
        workload: 'images tint $count',
        metric: 'mutation',
        count: count,
        operations: count,
        body: () {
          phase = !phase;
          final color = phase ? const ui.Color(0xffcceeff) : const ui.Color(0xffffffff);
          for (final node in independent.nodes) {
            node.tint = color;
          }
        },
        configuration: const <String, Object?>{'strategy': 'GImage_nodes'},
      );
      harness.measureSync(
        suite: _suite,
        workload: 'batch tint $count',
        metric: 'mutation',
        count: count,
        operations: count,
        body: () {
          phase = !phase;
          final color = phase ? const ui.Color(0xffcceeff) : const ui.Color(0xffffffff);
          for (final instance in batched.imageInstances) {
            instance.color = color;
          }
        },
        configuration: const <String, Object?>{'strategy': 'GImageBatch'},
      );

      independent.dispose();
      batched.dispose();
    }
  } finally {
    texture.dispose();
    image.dispose();
  }
  print('');
}

void _measurePointerRouting(
  GraphXBenchmarkHarness harness,
  _BenchScene scene,
  int count, {
  required bool disabledSubtree,
}) {
  final boundary = GPointerBoundaryEvent(
    type: GPointerBoundaryEventType.enter,
    pointer: 1,
    kind: GPointerDeviceKind.mouse,
    x: 1,
    y: 1,
    timestamp: Duration.zero,
  );
  scene.stage.input.dispatchPointerBoundary(boundary);
  final event = GPointerEvent(
    type: GPointerEventType.hover,
    pointer: 1,
    kind: GPointerDeviceKind.mouse,
    x: 1,
    y: 1,
    deltaX: 0,
    deltaY: 0,
    buttons: 0,
    timestamp: Duration.zero,
  );
  harness.measureSync(
    suite: _suite,
    workload: disabledSubtree ? 'pointer disabled $count' : 'pointer shallow $count',
    metric: 'route',
    count: count,
    operations: count,
    body: () => scene.stage.input.dispatchPointer(event),
    configuration: <String, Object?>{
      'disabled_subtree': disabledSubtree,
      'target': disabledSubtree ? 'none' : 'first_child',
    },
  );
}

void _measureRender(
  GraphXBenchmarkHarness harness, {
  required String workload,
  required _BenchScene scene,
  required int count,
  void Function()? beforeRender,
  Map<String, Object?> configuration = const <String, Object?>{},
}) {
  ui.PictureRecorder? recorder;
  ui.Canvas? canvas;
  harness.measureSync(
    suite: _suite,
    workload: workload,
    metric: 'record',
    count: count,
    operations: count,
    beforeSample: () {
      beforeRender?.call();
      final nextRecorder = ui.PictureRecorder();
      recorder = nextRecorder;
      canvas = ui.Canvas(nextRecorder);
    },
    body: () {
      scene.renderer.render(canvas!, scene.stage);
    },
    afterSample: () {
      final picture = recorder!.endRecording();
      picture.dispose();
      recorder = null;
      canvas = null;
    },
    configuration: configuration,
  );
}

_BenchScene _buildFlatScene(int count) {
  final root = GRoot();
  final nodes = <GNode>[];
  for (var i = 0; i < count; ++i) {
    final x = (i % 100) * 12.0;
    final y = (i ~/ 100) * 12.0;
    final leaf = root.addChild(_BenchLeaf(x: x, y: y));
    nodes.add(leaf);
  }
  return _mount(root, nodes: nodes);
}

_BenchScene _buildTransformScene(int count) {
  final root = GRoot();
  final nodes = <GNode>[];
  final groups = <GNode>[];
  const perGroup = 100;
  final groupCount = (count + perGroup - 1) ~/ perGroup;
  for (var groupIndex = 0; groupIndex < groupCount; ++groupIndex) {
    final group = root.addChild(GNode(name: 'group-$groupIndex'));
    group.y = groupIndex * 12.0;
    groups.add(group);
    final start = groupIndex * perGroup;
    final end = math.min(count, start + perGroup);
    for (var i = start; i < end; ++i) {
      final leaf = group.addChild(_BenchLeaf());
      leaf.x = (i - start) * 12.0;
      nodes.add(leaf);
    }
  }
  return _mount(root, nodes: nodes, groups: groups);
}

_BenchScene _buildGraphicsScene(int count, {required bool complex}) {
  final root = GRoot();
  final shapes = <GShape>[];
  final paths = <ui.Path>[];
  for (var i = 0; i < count; ++i) {
    final shape = root.addChild(GShape());
    shape.x = (i % 100) * 12.0;
    shape.y = (i ~/ 100) * 12.0;
    if (complex) {
      final path = _complexPath(i);
      paths.add(path);
      shape.graphics.lineStyle(1.5, const ui.Color(0xff59d9d0));
      shape.graphics.drawPath(path);
    } else {
      shape.graphics.beginFill(const ui.Color(0xff59d9d0));
      shape.graphics.drawRect(0, 0, 8, 8);
      shape.graphics.endFill();
    }
    shapes.add(shape);
  }
  return _mount(root, nodes: shapes, shapes: shapes, paths: paths);
}

ui.Path _complexPath(int index) {
  final path = ui.Path();
  path.moveTo(0, 0);
  for (var i = 1; i <= 48; ++i) {
    final x = i * .45;
    final y = ((i + index) % 7) * 1.15;
    path.lineTo(x, y);
  }
  return path;
}

_BenchScene _buildCacheScene(int count) {
  final root = GRoot();
  final target = root.addChild(GNode(name: 'cache-target'));
  final left = target.addChild(GNode(name: 'cache-left'));
  final right = target.addChild(GNode(name: 'cache-right'));
  final nodes = <GNode>[];
  _BenchLeaf? mutable;
  for (var i = 0; i < count; ++i) {
    final leaf = left.addChild(
      _BenchLeaf(x: (i % 100) * 10.0, y: (i ~/ 100) * 10.0, width: 7, height: 7),
    );
    nodes.add(leaf);
    if (i == count ~/ 2) mutable = leaf;
  }
  return _mount(
    root,
    nodes: nodes,
    cacheTarget: target,
    cacheLeft: left,
    cacheRight: right,
    mutableLeaf: mutable,
  );
}

_BenchScene _buildHitScene(int count, {required bool transformed}) {
  final root = GRoot();
  final nodes = <GNode>[];
  for (var i = 0; i < count; ++i) {
    final far = i == 0 ? 0.0 : 10000.0 + i * 8.0;
    final leaf = transformed ? _BenchLeaf() : _BenchLeaf(x: far, y: far);
    root.addChild(leaf);
    if (transformed) {
      leaf.x = far;
      leaf.y = far;
    }
    nodes.add(leaf);
  }
  return _mount(root, nodes: nodes);
}

_BenchScene _buildPointerScene(int count, {required bool disabledSubtree}) {
  final root = GRoot();
  final group = root.addChild(GNode(name: 'pointer-group'));
  final nodes = <GNode>[];
  for (var i = 0; i < count; ++i) {
    final far = i == 0 ? 0.0 : 10000.0 + i * 8.0;
    final leaf = group.addChild(_BenchLeaf(x: far, y: far));
    leaf.pointer.onMove.add((_) {});
    nodes.add(leaf);
  }
  if (disabledSubtree) group.pointer.enabled = false;
  return _mount(root, nodes: nodes, groups: <GNode>[group]);
}

_BenchScene _buildDeepHitScene(int depth) {
  final root = GRoot();
  GNode parent = root;
  final nodes = <GNode>[];
  for (var i = 0; i < depth - 1; ++i) {
    final child = parent.addChild(GNode());
    nodes.add(child);
    parent = child;
  }
  final leaf = parent.addChild(_BenchLeaf());
  nodes.add(leaf);
  return _mount(root, nodes: nodes);
}

_BenchScene _buildImageScene(GTexture texture, int count) {
  final root = GRoot();
  final nodes = <GNode>[];
  for (var i = 0; i < count; ++i) {
    final image = root.addChild(GImage(texture));
    image.x = (i % 100) * 10.0;
    image.y = (i ~/ 100) * 10.0;
    nodes.add(image);
  }
  return _mount(root, nodes: nodes);
}

_BenchScene _buildImageBatchScene(GTexture texture, int count) {
  final root = GRoot();
  final batch = root.addChild(GImageBatch(capacity: count));
  final instances = <GImageInstance>[];
  for (var i = 0; i < count; ++i) {
    final instance = batch.add(
      texture,
      x: (i % 100) * 10.0,
      y: (i ~/ 100) * 10.0,
    );
    instances.add(instance);
  }
  return _mount(
    root,
    nodes: <GNode>[batch],
    imageInstances: instances,
  );
}

_BenchScene _mount(
  GRoot root, {
  List<GNode> nodes = const <GNode>[],
  List<GNode> groups = const <GNode>[],
  List<GShape> shapes = const <GShape>[],
  List<ui.Path> paths = const <ui.Path>[],
  GNode? cacheTarget,
  GNode? cacheLeft,
  GNode? cacheRight,
  _BenchLeaf? mutableLeaf,
  List<GImageInstance> imageInstances = const <GImageInstance>[],
}) {
  final stage = GStage(root);
  stage.mount();
  stage.setViewport(1280, 1280, devicePixelRatio: 1);
  return _BenchScene(
    stage: stage,
    renderer: GCanvasRenderer(),
    nodes: nodes,
    groups: groups,
    shapes: shapes,
    paths: paths,
    cacheTarget: cacheTarget,
    cacheLeft: cacheLeft,
    cacheRight: cacheRight,
    mutableLeaf: mutableLeaf,
    imageInstances: imageInstances,
  );
}

final class _BenchScene {
  _BenchScene({
    required this.stage,
    required this.renderer,
    required this.nodes,
    required this.groups,
    required this.shapes,
    required this.paths,
    required this.cacheTarget,
    required this.cacheLeft,
    required this.cacheRight,
    required this.mutableLeaf,
    required this.imageInstances,
  });

  final GStage stage;
  final GCanvasRenderer renderer;
  final List<GNode> nodes;
  final List<GNode> groups;
  final List<GShape> shapes;
  final List<ui.Path> paths;
  final GNode? cacheTarget;
  final GNode? cacheLeft;
  final GNode? cacheRight;
  final _BenchLeaf? mutableLeaf;
  final List<GImageInstance> imageInstances;

  void dispose() {
    renderer.dispose();
    stage.dispose();
  }
}

final class _BenchLeaf extends GNode {
  _BenchLeaf({
    double x = 0,
    double y = 0,
    double width = 8,
    double height = 8,
  }) : _x = x,
       _y = y,
       _width = width,
       _height = height {
    setPaintSelf(true);
  }

  static final ui.Paint _paint = _createPaint();

  static ui.Paint _createPaint() {
    final paint = ui.Paint();
    paint.color = const ui.Color(0xff59d9d0);
    return paint;
  }

  final double _x;
  final double _y;
  double _width;
  double _height;

  void resize(double width, double height) {
    if (_width == width && _height == height) return;
    _width = width;
    _height = height;
    invalidateBounds();
    invalidatePaint();
  }

  @override
  void computeSelfBounds(GBounds out) {
    out.setXYWH(_x, _y, _width, _height);
  }

  @override
  void paintSelf(GRenderContext context) {
    context.canvas.drawRect(ui.Rect.fromLTWH(_x, _y, _width, _height), _paint);
  }
}
