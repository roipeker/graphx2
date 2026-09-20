// Copyright (c) 2026 GraphX by roipeker.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:graphx/graphx.dart';

const _smokeMode = bool.fromEnvironment('GRAPHX_PERFORMANCE_LAB_SMOKE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final texture = await _makeTexture();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _PerformanceLab(texture: texture),
    ),
  );
}

Future<GTexture> _makeTexture() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint();
  paint.color = const ui.Color(0xff59d9d0);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), paint);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(8, 8);
    return GTexture.owned(image);
  } finally {
    picture.dispose();
  }
}

enum _LabScenario {
  staticScene,
  movingTransforms,
  graphicsRebuild,
  cacheLive,
  cacheWarm,
  imageNodes,
  imageBatch,
  pointerRouting,
}

extension on _LabScenario {
  String get label => switch (this) {
    _LabScenario.staticScene => 'Static retained',
    _LabScenario.movingTransforms => 'Moving transforms',
    _LabScenario.graphicsRebuild => 'Graphics clear + redraw',
    _LabScenario.cacheLive => 'Moving subtree / live',
    _LabScenario.cacheWarm => 'Moving subtree / cached',
    _LabScenario.imageNodes => 'Moving GImage nodes',
    _LabScenario.imageBatch => 'Moving GImageBatch',
    _LabScenario.pointerRouting => 'Pointer routing',
  };
}

final class _PerformanceLab extends StatefulWidget {
  const _PerformanceLab({required this.texture});

  final GTexture texture;

  @override
  State<_PerformanceLab> createState() => _PerformanceLabState();
}

final class _PerformanceLabState extends State<_PerformanceLab> {
  _LabScenario _scenario = _LabScenario.staticScene;
  int _count = 1000;
  double _fps = 0;
  double _frameMs = 0;
  int _nodeCount = 0;
  String _cacheState = 'n/a';
  int _hitEvents = 0;
  late final Stopwatch _hudThrottle;
  Timer? _smokeTimer;

  @override
  void initState() {
    super.initState();
    _hudThrottle = Stopwatch();
    _hudThrottle.start();
    if (_smokeMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSmokeCycle());
    }
  }

  @override
  void dispose() {
    _smokeTimer?.cancel();
    widget.texture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sceneKey = ValueKey<String>('${_scenario.name}:$_count');
    return Scaffold(
      backgroundColor: const Color(0xff101114),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GraphXView.scene(
              (root) => _buildScenario(root),
              key: sceneKey,
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: _buildHud(),
          ),
        ],
      ),
    );
  }

  Widget _buildHud() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xdd181a1f),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            DropdownButton<_LabScenario>(
              value: _scenario,
              dropdownColor: const Color(0xff24272e),
              items: _LabScenario.values
                  .map(
                    (scenario) => DropdownMenuItem<_LabScenario>(
                      value: scenario,
                      child: Text(scenario.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (scenario) {
                if (scenario == null || scenario == _scenario) return;
                setState(() {
                  _scenario = scenario;
                  _resetHud();
                });
              },
            ),
            DropdownButton<int>(
              value: _count,
              dropdownColor: const Color(0xff24272e),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 1000, child: Text('1,000')),
                DropdownMenuItem<int>(value: 10000, child: Text('10,000')),
              ],
              onChanged: (count) {
                if (count == null || count == _count) return;
                setState(() {
                  _count = count;
                  _resetHud();
                });
              },
            ),
            Text('FPS ${_fps.toStringAsFixed(1)}'),
            Text('frame ${_frameMs.toStringAsFixed(2)} ms'),
            Text('nodes $_nodeCount'),
            Text('cache $_cacheState'),
            if (_scenario == _LabScenario.pointerRouting) Text('pointer events $_hitEvents'),
          ],
        ),
      ),
    );
  }

  void _resetHud() {
    _fps = 0;
    _frameMs = 0;
    _nodeCount = 0;
    _cacheState = 'n/a';
    _hitEvents = 0;
  }

  void _startSmokeCycle() {
    if (!mounted) return;
    var nextIndex = 1;
    debugPrint('GRAPHX_PERFORMANCE_LAB_SMOKE start');
    _smokeTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (nextIndex >= _LabScenario.values.length) {
        timer.cancel();
        debugPrint('GRAPHX_PERFORMANCE_LAB_SMOKE complete');
        return;
      }
      setState(() {
        _scenario = _LabScenario.values[nextIndex];
        nextIndex++;
        _resetHud();
      });
    });
  }

  void _buildScenario(GRoot root) {
    if (_smokeMode) {
      debugPrint(
        'GRAPHX_PERFORMANCE_LAB_SCENARIO ${_scenario.name}:$_count',
      );
    }
    String Function() cacheState = () => 'n/a';
    void Function(int frame, double delta) mutate = (_, _) {};

    switch (_scenario) {
      case _LabScenario.staticScene:
        _addRects(root, _count);

      case _LabScenario.movingTransforms:
        final nodes = _addRects(root, _count, transformed: true);
        mutate = (frame, _) {
          final offset = frame.isEven ? .25 : -.25;
          final scale = frame.isEven ? 1.01 : .99;
          for (final node in nodes) {
            node.x += offset;
            node.y -= offset;
            node.rotation += offset * .01;
            node.scaleX = scale;
            node.scaleY = scale;
          }
        };

      case _LabScenario.graphicsRebuild:
        final shapes = _addGraphics(root, _count);
        mutate = (frame, _) {
          final inset = frame.isEven ? .5 : 0.0;
          for (final shape in shapes) {
            final graphics = shape.graphics;
            graphics.clear();
            graphics.beginFill(const ui.Color(0xff59d9d0));
            graphics.drawRect(inset, inset, 6 - inset, 6 - inset);
            graphics.endFill();
          }
        };

      case _LabScenario.cacheLive:
        final group = root.addChild(GNode(name: 'live-subtree'));
        _addRects(group, _count);
        mutate = (frame, _) {
          group.x += frame.isEven ? .5 : -.5;
          group.rotation += frame.isEven ? .002 : -.002;
        };
        cacheState = () => 'disabled';

      case _LabScenario.cacheWarm:
        final group = root.addChild(GNode(name: 'cached-subtree'));
        _addRects(group, _count);
        group.cache.scale = 1;
        group.cache.enabled = true;
        mutate = (frame, _) {
          group.x += frame.isEven ? .5 : -.5;
          group.rotation += frame.isEven ? .002 : -.002;
        };
        cacheState = () {
          if (group.cache.isReady) return 'ready';
          if (group.cache.isBuilding) return 'building';
          return 'dirty';
        };

      case _LabScenario.imageNodes:
        final images = <GImage>[];
        for (var i = 0; i < _count; ++i) {
          final image = root.addChild(GImage(widget.texture));
          image.x = (i % 80) * 9.0;
          image.y = 90 + (i ~/ 80) * 9.0;
          images.add(image);
        }
        mutate = (frame, _) {
          final offset = frame.isEven ? .25 : -.25;
          for (final image in images) {
            image.x += offset;
            image.y -= offset;
          }
        };

      case _LabScenario.imageBatch:
        final batch = root.addChild(GImageBatch(capacity: _count));
        final instances = <GImageInstance>[];
        for (var i = 0; i < _count; ++i) {
          final instance = batch.add(
            widget.texture,
            x: (i % 80) * 9.0,
            y: 90 + (i ~/ 80) * 9.0,
          );
          instances.add(instance);
        }
        mutate = (frame, _) {
          final offset = frame.isEven ? .25 : -.25;
          for (final instance in instances) {
            instance.setPosition(instance.x + offset, instance.y - offset);
          }
        };

      case _LabScenario.pointerRouting:
        final nodes = _addRects(root, _count, transformed: true);
        for (final node in nodes) {
          node.pointer.onMove.add((_) {
            _hitEvents++;
          });
        }
    }

    final driver = _LabDriver(
      mutate: mutate,
      sample: (stage) => _sampleStats(stage, cacheState()),
    );
    root.addChild(driver);
  }

  List<_LabRect> _addRects(
    GNode parent,
    int count, {
    bool transformed = false,
  }) {
    final nodes = <_LabRect>[];
    for (var i = 0; i < count; ++i) {
      final x = (i % 80) * 8.0;
      final y = 90 + (i ~/ 80) * 8.0;
      final node = transformed ? _LabRect() : _LabRect(originX: x, originY: y);
      parent.addChild(node);
      if (transformed) {
        node.x = x;
        node.y = y;
      }
      nodes.add(node);
    }
    return nodes;
  }

  List<GShape> _addGraphics(GNode parent, int count) {
    final shapes = <GShape>[];
    for (var i = 0; i < count; ++i) {
      final shape = parent.addChild(GShape());
      shape.x = (i % 80) * 8.0;
      shape.y = 90 + (i ~/ 80) * 8.0;
      shape.graphics.beginFill(const ui.Color(0xff59d9d0));
      shape.graphics.drawRect(0, 0, 6, 6);
      shape.graphics.endFill();
      shapes.add(shape);
    }
    return shapes;
  }

  void _sampleStats(GStage stage, String cacheState) {
    if (_hudThrottle.elapsedMilliseconds < 250) return;
    _hudThrottle.reset();
    final stats = stage.stats;
    if (!mounted) return;
    setState(() {
      _fps = stats.frame.fps;
      _frameMs = stats.frame.lastFrameMilliseconds;
      _nodeCount = stats.scene.nodeCount;
      _cacheState = cacheState;
    });
  }
}

final class _LabDriver extends GNode {
  _LabDriver({required this.mutate, required this.sample}) {
    updatesEnabled = true;
  }

  final void Function(int frame, double delta) mutate;
  final void Function(GStage stage) sample;
  int _frame = 0;

  @override
  void attached() {
    stage.stats.enabled = true;
  }

  @override
  void update(double delta) {
    _frame++;
    mutate(_frame, delta);
    sample(stage);
  }
}

final class _LabRect extends GNode {
  _LabRect({this.originX = 0, this.originY = 0}) {
    setPaintSelf(true);
  }

  static final ui.Paint _paint = _makePaint();

  static ui.Paint _makePaint() {
    final paint = ui.Paint();
    paint.color = const ui.Color(0xff59d9d0);
    return paint;
  }

  final double originX;
  final double originY;

  @override
  void computeSelfBounds(GBounds out) {
    out.setXYWH(originX, originY, 6, 6);
  }

  @override
  void paintSelf(GRenderContext context) {
    context.canvas.drawRect(
      ui.Rect.fromLTWH(originX, originY, 6, 6),
      _paint,
    );
  }
}
