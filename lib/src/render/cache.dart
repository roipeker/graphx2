part of 'package:graphx/src/graphx_impl.dart';

/// Retained raster-cache controls for one node subtree.
///
/// The cache is allocated lazily on first access. By default GraphX chooses a
/// backing scale from the node's effective world scale and stage DPR when the
/// node is hosted. Detached preparation uses a neutral 1x automatic scale until
/// the node is attached. Set [scale] to a positive value to pin the backing
/// resolution explicitly.
final class GNodeCache implements _GDisposable {
  GNodeCache._(this._node);

  static const _autoMaxPixels = 4 * 1024 * 1024;
  static const _autoMaxDimension = 4096.0;

  final GNode _node;
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.low;
  bool _enabled = false;
  double? _scale;
  GTexture? _texture;
  GRect? _bounds;
  int _contentVersion = 0;
  int _capturedVersion = -1;
  int _captures = 0;
  int _retainedBytes = 0;
  bool _scheduled = false;
  Future<void>? _buildFuture;
  double _rasterScale = 0.0;
  double _pendingViewScale = 1.0;
  bool _disposed = false;
  GStage? _registeredStage;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _syncStageRegistration();
    if (value) {
      _node._stage?.requestPaint();
    } else {
      clear();
    }
  }

  /// Fixed backing-image pixels per logical unit, or null for automatic scale.
  ///
  /// Automatic scale is bounded by an internal memory-safe raster budget.
  /// A fixed value is an explicit request and is not reduced by that policy.
  double? get scale => _scale;
  set scale(double? value) {
    if (value != null && (!value.isFinite || value <= 0.0)) {
      throw ArgumentError.value(
        value,
        'scale',
        'Must be null or finite and > 0.',
      );
    }
    if (_scale == value) return;
    _scale = value;
    _node._stage?.requestPaint();
  }

  bool get isReady => _texture != null && _capturedVersion == _contentVersion;
  bool get isDirty => _capturedVersion != _contentVersion;
  bool get isBuilding => _buildFuture != null || _scheduled;
  double get rasterScale => _rasterScale;
  int get captures => _captures;
  int get pixelWidth => _texture?.image.width ?? 0;
  int get pixelHeight => _texture?.image.height ?? 0;

  /// Ensures a usable cache is ready now. Intended for optional warm-up before
  /// first display; it is a no-op when current pixels already satisfy quality.
  ///
  /// This may be called while the node is detached. Automatic scale uses 1x in
  /// that case and can be promoted after attachment; set [scale] when a known
  /// backing resolution is required before the node enters a Stage.
  Future<void> prepare() async {
    if (_disposed || _node.isDisposed) return;
    if (!_enabled) enabled = true;
    final desired = _desiredScale();
    if (!_needsPromotion(desired)) return;
    await _startBuild(desired);
  }

  /// Drops the retained raster. Content remains live and can be rebuilt later.
  void clear() {
    _texture?.dispose();
    _texture = null;
    _setRetainedBytes(0);
    _bounds = null;
    _capturedVersion = -1;
    _rasterScale = 0.0;
    _pendingViewScale = 1.0;
    _node._stage?.requestPaint();
  }

  void _invalidate() {
    _contentVersion++;
  }

  void _attachStage(GStage stage) {
    if (_enabled) _registerStage(stage);
  }

  void _detachStage(GStage stage) {
    if (identical(_registeredStage, stage)) _unregisterStage();
  }

  void _syncStageRegistration() {
    final stage = _node._stage;
    if (_enabled && stage != null) {
      _registerStage(stage);
    } else {
      _unregisterStage();
    }
  }

  void _registerStage(GStage stage) {
    if (identical(_registeredStage, stage)) return;
    _unregisterStage();
    _registeredStage = stage;
    stage._rasterCacheCount += 1;
    stage._rasterCacheBytes += _retainedBytes;
  }

  void _unregisterStage() {
    final stage = _registeredStage;
    if (stage == null) return;
    _registeredStage = null;
    stage._rasterCacheCount -= 1;
    stage._rasterCacheBytes -= _retainedBytes;
    assert(stage._rasterCacheCount >= 0);
    assert(stage._rasterCacheBytes >= 0);
  }

  double _desiredScale([double viewScale = 1.0]) {
    final fixed = _scale;
    if (fixed != null) return fixed;
    final stage = _node._stage;
    if (stage == null) return 1.0;
    _node._ensureWorldTransform();
    final m = _node._worldMatrix!;
    final sx = math.sqrt(m.a * m.a + m.b * m.b);
    final sy = math.sqrt(m.c * m.c + m.d * m.d);
    var desired = (math.max(sx, sy) * viewScale * stage.devicePixelRatio)
        .clamp(0.5, 4.0)
        .toDouble();
    final bounds = _bounds;
    if (bounds != null) desired = _limitAutoScale(desired, bounds);
    return desired;
  }

  double _limitAutoScale(double desired, GRect bounds) {
    if (_scale != null || bounds.w <= 0.0 || bounds.h <= 0.0) return desired;
    final areaScale = math.sqrt(_autoMaxPixels / (bounds.w * bounds.h));
    final dimensionScale = math.min(
      _autoMaxDimension / bounds.w,
      _autoMaxDimension / bounds.h,
    );
    return math.min(desired, math.min(areaScale, dimensionScale));
  }

  bool _needsPromotion(double desired) {
    if (_texture == null || _texture!.isDisposed) return true;
    if (_capturedVersion != _contentVersion) return true;
    if (_scale != null) return (_rasterScale - desired).abs() > 1e-6;
    // Hysteresis keeps zoom animations from continuously rebuilding a cache.
    return desired > _rasterScale * 1.25;
  }

  void _ensureScheduled({double viewScale = 1.0}) {
    if (viewScale.isFinite && viewScale > _pendingViewScale) {
      _pendingViewScale = viewScale;
    }
    if (!_enabled || _disposed || _scheduled || _buildFuture != null) return;
    final desired = _desiredScale(_pendingViewScale);
    if (!_needsPromotion(desired)) {
      _pendingViewScale = 1.0;
      return;
    }
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (_enabled && !_disposed && !_node.isDisposed) {
        final pending = _pendingViewScale;
        _pendingViewScale = 1.0;
        unawaited(_startBuild(_desiredScale(pending)));
      }
    });
  }

  Future<void> _startBuild(double desiredScale) {
    final current = _buildFuture;
    if (current != null) return current;

    late final Future<void> future;
    future = _build(desiredScale).whenComplete(() {
      if (identical(_buildFuture, future)) _buildFuture = null;
      if (_enabled && !_disposed) {
        _ensureScheduled(viewScale: _pendingViewScale);
      }
    });
    _buildFuture = future;
    return future;
  }

  Future<void> _build(double desiredScale) async {
    if (_disposed || _node.isDisposed) return;
    final version = _contentVersion;
    final effect = _node.getEffectBounds();
    if (effect.isEmpty) return;
    final bounds = GRect(effect.x1, effect.y1, effect.width, effect.height);
    desiredScale = _limitAutoScale(desiredScale, bounds);

    final activeStats = _node._stage?._activeStats;
    final watch = activeStats == null ? null : (Stopwatch()..start());
    final texture = await _snapshotCacheSource(_node, bounds, desiredScale);
    if (watch != null) {
      watch.stop();
      activeStats!.cache.rasterize.record(watch.elapsedMicroseconds);
    }
    if (!_enabled ||
        _disposed ||
        _node.isDisposed ||
        version != _contentVersion) {
      texture.dispose();
      return;
    }

    final previous = _texture;
    _texture = texture;
    _setRetainedBytes(texture.image.width * texture.image.height * 4);
    _bounds = bounds;
    _capturedVersion = version;
    _rasterScale = desiredScale;
    _captures++;
    previous?.dispose();
    _node._stage?.requestPaint();
  }

  void _setRetainedBytes(int value) {
    if (_retainedBytes == value) return;
    final stage = _registeredStage;
    if (stage != null) stage._rasterCacheBytes += value - _retainedBytes;
    _retainedBytes = value;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregisterStage();
    _texture?.dispose();
    _texture = null;
    _setRetainedBytes(0);
    _bounds = null;
  }
}

extension GNodeCaching on GNode {
  /// Lazy retained-raster domain for this subtree.
  GNodeCache get cache => (_cache ??= GNodeCache._(this));
}

extension _GCanvasCacheRenderer on GCanvasRenderer {
  /// Returns true when the node was replaced by a valid retained raster.
  bool _tryPaintCache(
    GNode node,
    GRenderContext context,
    double parentAlpha,
    GRenderStats? stats,
  ) {
    final cache = node._cache;
    if (cache == null || !cache.enabled) return false;

    // Filtered views must traverse retained render-group boundaries. An
    // ancestor raster may otherwise contain pixels belonging to groups excluded
    // by this pass. Keep one camera-independent cache rather than multiplying
    // retained textures by mask combinations.
    if (context.renderMask.bits != GRenderMask.all.bits) return false;

    cache._ensureScheduled(viewScale: context.viewScale);

    final texture = cache._texture;
    final bounds = cache._bounds;
    if (!cache.isReady ||
        texture == null ||
        bounds == null ||
        texture.isDisposed) {
      return false;
    }

    final canvas = context.canvas;
    final transformed = node.hasLocalTransform;
    if (transformed) {
      stats?.canvasSaves.increment();
      canvas.save();
      stats?.transformsApplied.increment();
      context.transform(node.localMatrix);
    }

    final previousAlpha = context.alpha;
    context.alpha = parentAlpha;
    try {
      final paint = cache._paint..blendMode = node.blendMode;
      if (context.hasColorTransform) {
        paint
          ..color = const ui.Color(0xffffffff)
          ..colorFilter = context._effectiveColorFilter;
      } else {
        paint
          ..color = ui.Color.fromARGB(
            (parentAlpha * 255.0).round().clamp(0, 255).toInt(),
            255,
            255,
            255,
          )
          ..colorFilter = null;
      }
      canvas.drawImageRect(
        texture.image,
        ui.Rect.fromLTWH(
          0.0,
          0.0,
          texture.image.width.toDouble(),
          texture.image.height.toDouble(),
        ),
        ui.Rect.fromLTWH(bounds.x, bounds.y, bounds.w, bounds.h),
        paint,
      );
    } finally {
      context.alpha = previousAlpha;
      if (transformed) canvas.restore();
    }
    return true;
  }
}
