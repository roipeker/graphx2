part of 'package:graphx/graphx.dart';

/// Hit area backed directly by the stroked batches of one [GGraphics].
///
/// It observes retained batch identity/geometry versions and lazily rebuilds
/// its own sampled segment cache when those change.
final class GGraphicsStrokeHitArea implements GHitArea {
  GGraphicsStrokeHitArea(this.graphics, double width)
    : _cache = _GStrokeHitCache(width);

  final GGraphics graphics;
  final _GStrokeHitCache _cache;
  final List<int> _indexes = <int>[];
  final List<_GGraphicsBatch> _batches = <_GGraphicsBatch>[];
  final List<int> _versions = <int>[];
  int _sourceCount = -1;
  bool _built = false;

  double get width => _cache.width;

  @override
  bool contains(double x, double y) {
    _ensureCurrent();
    return _cache.contains(x, y);
  }

  /// Copies the current sampled stroke-cache AABB into [out].
  void getApproximateBounds(GBounds out) {
    _ensureCurrent();
    _cache.getBounds(out);
  }

  /// Squared distance to the same flattened centerline used by [contains].
  ///
  /// When [nearest] is supplied, it receives the closest sampled point.
  double distanceSquaredTo(double x, double y, [GPoint? nearest]) {
    _ensureCurrent();
    return _cache.distanceSquaredTo(x, y, nearest);
  }

  void _ensureCurrent() {
    if (!_built || _changed()) _rebuild();
  }

  bool _changed() {
    final source = graphics._batches;
    if (source.length != _sourceCount) return true;
    for (var i = 0; i < _batches.length; ++i) {
      final batch = source[_indexes[i]];
      if (!identical(_batches[i], batch) ||
          _versions[i] != batch.geometryVersion) {
        return true;
      }
    }
    return false;
  }

  void _rebuild() {
    _indexes.clear();
    _batches.clear();
    _versions.clear();
    final paths = <Path>[];
    final source = graphics._batches;
    _sourceCount = source.length;
    for (var i = 0; i < source.length; ++i) {
      final batch = source[i];
      if (batch.stroke == null) continue;
      _indexes.add(i);
      _batches.add(batch);
      _versions.add(batch.geometryVersion);
      paths.add(batch.path);
    }
    _cache.rebuild(paths);
    _built = true;
  }
}

/// Pointer hit-area conveniences for retained Graphics geometry.
extension GGraphicsHitArea on GGraphics {
  /// Creates an opt-in selectable corridor around this Graphics object's
  /// stroked batches. [width] is the complete interaction width and is
  /// independent of the visual stroke thickness.
  ///
  /// The returned hit area owns its lazy flattened cache. Graphics itself
  /// remains interaction-agnostic.
  GGraphicsStrokeHitArea strokeHitArea(double width) =>
      GGraphicsStrokeHitArea(this, width);
}
