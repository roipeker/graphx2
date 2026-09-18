part of 'package:graphx/graphx.dart';

abstract interface class GStatsMetric {
  String get name;
  void reset();
}

final class GStatsCounterMetric implements GStatsMetric {
  GStatsCounterMetric(this.name);
  @override
  final String name;
  int value = 0;
  void increment([int amount = 1]) {
    assert(amount >= 0);
    value += amount;
  }

  @override
  void reset() => value = 0;
  @override
  String toString() => '$name=$value';
}

final class GStatsTimerMetric implements GStatsMetric {
  GStatsTimerMetric(this.name);
  @override
  final String name;
  int count = 0;
  int lastMicroseconds = 0;
  int maxMicroseconds = 0;
  int totalMicroseconds = 0;
  double get averageMicroseconds =>
      count == 0 ? 0.0 : totalMicroseconds / count;
  void record(int microseconds) {
    assert(microseconds >= 0);
    lastMicroseconds = microseconds;
    totalMicroseconds += microseconds;
    count++;
    if (microseconds > maxMicroseconds) maxMicroseconds = microseconds;
  }

  @override
  void reset() {
    count = 0;
    lastMicroseconds = 0;
    maxMicroseconds = 0;
    totalMicroseconds = 0;
  }

  @override
  String toString() =>
      '$name last=${_formatDuration(lastMicroseconds)} avg=${_formatDuration(averageMicroseconds.round())} max=${_formatDuration(maxMicroseconds)} count=$count';
}

/// Live scene facts maintained by the engine regardless of instrumentation.
final class GSceneStats {
  GSceneStats._(this._stage);

  final GStage _stage;

  /// Nodes currently attached to the Stage, including its root.
  int get nodeCount => _stage._nodeCount;
}

/// Host-frame cadence and synchronous update CPU timing.
///
/// [fps] is frames / elapsed host time, never an average of instantaneous FPS.
/// After the first half-second warmup it updates in stable 500 ms windows.
final class GFrameStats {
  GFrameStats(GStats owner)
    : update = owner._register(GStatsTimerMetric('frame.update'));

  static const _sampleWindowSeconds = .5;

  final GStatsTimerMetric update;

  int frames = 0;
  double fps = 0.0;

  /// Average host interval for the published cadence sample.
  double frameMilliseconds = 0.0;

  /// Most recent host interval.
  double lastFrameMilliseconds = 0.0;

  /// Largest host interval in the published cadence sample.
  double maxFrameMilliseconds = 0.0;

  int _sampleFrames = 0;
  double _sampleSeconds = 0.0;
  double _sampleMaxMilliseconds = 0.0;
  bool _warmedUp = false;

  void record(double delta) {
    if (!delta.isFinite || delta <= 0.0) return;

    final milliseconds = delta * 1000.0;
    frames++;
    lastFrameMilliseconds = milliseconds;
    _sampleFrames++;
    _sampleSeconds += delta;
    if (milliseconds > _sampleMaxMilliseconds) {
      _sampleMaxMilliseconds = milliseconds;
    }

    // Give diagnostics useful numbers immediately, then publish only complete
    // windows so a single short/long interval does not make the HUD jump.
    if (!_warmedUp || _sampleSeconds >= _sampleWindowSeconds) {
      fps = _sampleFrames / _sampleSeconds;
      frameMilliseconds = _sampleSeconds * 1000.0 / _sampleFrames;
      maxFrameMilliseconds = _sampleMaxMilliseconds;
    }

    if (_sampleSeconds >= _sampleWindowSeconds) {
      _warmedUp = true;
      _sampleFrames = 0;
      _sampleSeconds = 0.0;
      _sampleMaxMilliseconds = 0.0;
    }
  }

  void reset() {
    frames = 0;
    fps = 0.0;
    frameMilliseconds = 0.0;
    lastFrameMilliseconds = 0.0;
    maxFrameMilliseconds = 0.0;
    _sampleFrames = 0;
    _sampleSeconds = 0.0;
    _sampleMaxMilliseconds = 0.0;
    _warmedUp = false;
  }

  @override
  String toString() =>
      'frame fps=${fps.toStringAsFixed(1)} interval=${frameMilliseconds.toStringAsFixed(2)} ms max=${maxFrameMilliseconds.toStringAsFixed(2)} ms frames=$frames';
}

final class GRenderStats {
  GRenderStats(GStats owner)
    : paint = owner._register(GStatsTimerMetric('render.paint')),
      nodesVisited = owner._register(
        GStatsCounterMetric('render.nodesVisited'),
      ),
      nodesPainted = owner._register(
        GStatsCounterMetric('render.nodesPainted'),
      ),
      transformsApplied = owner._register(
        GStatsCounterMetric('render.transformsApplied'),
      ),
      canvasSaves = owner._register(GStatsCounterMetric('render.canvasSaves')),
      saveLayers = owner._register(GStatsCounterMetric('render.saveLayers')),
      clipsApplied = owner._register(
        GStatsCounterMetric('render.clipsApplied'),
      ),
      masksApplied = owner._register(
        GStatsCounterMetric('render.masksApplied'),
      ),
      cullChecks = owner._register(GStatsCounterMetric('render.cullChecks')),
      culledChildren = owner._register(
        GStatsCounterMetric('render.culledChildren'),
      );
  final GStatsTimerMetric paint;
  final GStatsCounterMetric nodesVisited;
  final GStatsCounterMetric nodesPainted;
  final GStatsCounterMetric transformsApplied;
  final GStatsCounterMetric canvasSaves;
  final GStatsCounterMetric saveLayers;
  final GStatsCounterMetric clipsApplied;
  final GStatsCounterMetric masksApplied;
  final GStatsCounterMetric cullChecks;
  final GStatsCounterMetric culledChildren;
}

/// Raster-cache facts and async rasterization timing.
final class GCacheStats {
  GCacheStats(GStats owner, this._stage)
    : rasterize = owner._register(GStatsTimerMetric('cache.rasterize'));

  final GStage _stage;
  final GStatsTimerMetric rasterize;

  int get active => _stage._rasterCacheCount;
  int get retainedBytes => _stage._rasterCacheBytes;
}

final class GTransformStats {
  GTransformStats(GStats owner)
    : invalidations = owner._register(
        GStatsCounterMetric('transform.invalidations'),
      ),
      localMatrixAssignments = owner._register(
        GStatsCounterMetric('transform.localMatrixAssignments'),
      ),
      localMatrixMaterializations = owner._register(
        GStatsCounterMetric('transform.localMatrixMaterializations'),
      ),
      localMatrixUpdates = owner._register(
        GStatsCounterMetric('transform.localMatrixUpdates'),
      ),
      worldMatrixUpdates = owner._register(
        GStatsCounterMetric('transform.worldMatrixUpdates'),
      ),
      worldMatrixCacheHits = owner._register(
        GStatsCounterMetric('transform.worldMatrixCacheHits'),
      ),
      localToGlobal = owner._register(
        GStatsCounterMetric('transform.localToGlobal'),
      ),
      globalToLocal = owner._register(
        GStatsCounterMetric('transform.globalToLocal'),
      );
  final GStatsCounterMetric invalidations;
  final GStatsCounterMetric localMatrixAssignments;
  final GStatsCounterMetric localMatrixMaterializations;
  final GStatsCounterMetric localMatrixUpdates;
  final GStatsCounterMetric worldMatrixUpdates;
  final GStatsCounterMetric worldMatrixCacheHits;
  final GStatsCounterMetric localToGlobal;
  final GStatsCounterMetric globalToLocal;
}

/// Paragraph activity. Counters are collected only while diagnostics are enabled.
final class GTextStats {
  GTextStats(GStats owner)
    : paragraphBuilds = owner._register(
        GStatsCounterMetric('text.paragraphBuilds'),
      ),
      paragraphLayouts = owner._register(
        GStatsCounterMetric('text.paragraphLayouts'),
      ),
      paragraphPaints = owner._register(
        GStatsCounterMetric('text.paragraphPaints'),
      );
  final GStatsCounterMetric paragraphBuilds;
  final GStatsCounterMetric paragraphLayouts;
  final GStatsCounterMetric paragraphPaints;
}

/// Stage diagnostics. The facade is lazy and detailed instrumentation is off
/// until [enabled] is set. Cheap live facts such as [scene] remain available.
final class GStats {
  GStats._(this._stage);

  final GStage _stage;
  final List<GStatsMetric> _metrics = <GStatsMetric>[];
  bool _enabled = false;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (value) reset();
  }

  late final GSceneStats scene = GSceneStats._(_stage);
  late final GFrameStats frame = GFrameStats(this);
  late final GRenderStats render = GRenderStats(this);
  late final GCacheStats cache = GCacheStats(this, _stage);
  late final GTransformStats transform = GTransformStats(this);
  late final GTextStats text = GTextStats(this);

  Iterable<GStatsMetric> get metrics => _metrics;

  T _register<T extends GStatsMetric>(T metric) {
    _metrics.add(metric);
    return metric;
  }

  void reset() {
    frame.reset();
    for (final metric in _metrics) {
      metric.reset();
    }
  }

  @override
  String toString() => '$frame\n${_metrics.join('\n')}';
}
