part of 'package:graphx/src/graphx_impl.dart';

/// Pointer-only local geometry override for [GNode.hitArea].
///
/// Hit areas do not affect rendering or canonical node bounds.
abstract interface class GHitArea {
  bool contains(double x, double y);

  factory GHitArea.rect(double x, double y, double width, double height) =
      GRectHitArea;

  factory GHitArea.circle(double x, double y, double radius) = GCircleHitArea;

  factory GHitArea.path(Path path) = GPathHitArea;

  /// Selectable corridor centered on [path]. [width] is the complete hit width,
  /// independent of any visual stroke width.
  factory GHitArea.pathStroke(Path path, double width) = GPathStrokeHitArea;
}

final class GRectHitArea implements GHitArea {
  const GRectHitArea(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  @override
  bool contains(double px, double py) =>
      px >= x && py >= y && px < x + width && py < y + height;
}

final class GCircleHitArea implements GHitArea {
  const GCircleHitArea(this.x, this.y, this.radius);

  final double x;
  final double y;
  final double radius;

  @override
  bool contains(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    return dx * dx + dy * dy <= radius * radius;
  }
}

final class GPathHitArea implements GHitArea {
  GPathHitArea(Path path) : path = Path.from(path);

  final Path path;

  @override
  bool contains(double x, double y) => path.contains(Offset(x, y));
}

/// Sampled selectable stroke corridor for an arbitrary retained [Path].
///
/// The source path is copied. Flattening is lazy and performed once; steady
/// hit tests are allocation-free squared-distance checks against cached
/// segments.
final class GPathStrokeHitArea implements GHitArea {
  GPathStrokeHitArea(Path path, double width)
    : path = Path.from(path),
      _cache = _GStrokeHitCache(width);

  final Path path;
  final _GStrokeHitCache _cache;
  bool _built = false;

  double get width => _cache.width;

  @override
  bool contains(double x, double y) {
    _ensureBuilt();
    return _cache.contains(x, y);
  }

  /// Copies the sampled stroke-cache AABB into [out].
  ///
  /// This is the same approximation used as the broad phase for [contains].
  void getApproximateBounds(GBounds out) {
    _ensureBuilt();
    _cache.getBounds(out);
  }

  /// Squared distance to the same flattened centerline used by [contains].
  ///
  /// When [nearest] is supplied, it receives the closest sampled point.
  double distanceSquaredTo(double x, double y, [GPoint? nearest]) {
    _ensureBuilt();
    return _cache.distanceSquaredTo(x, y, nearest);
  }

  void _ensureBuilt() {
    if (_built) return;
    _cache.rebuild(<Path>[path]);
    _built = true;
  }
}

/// Shared flattened stroke representation used by both public stroke-hit APIs.
final class _GStrokeHitCache {
  _GStrokeHitCache(this.width) {
    if (!width.isFinite || width <= 0.0) {
      throw ArgumentError.value(width, 'width', 'Must be finite and > 0.');
    }
    _radius = width * .5;
    _radiusSq = _radius * _radius;
  }

  final double width;
  late final double _radius;
  late final double _radiusSq;
  final GBounds _bounds = GBounds.empty();
  Float32List _segments = Float32List(0);
  bool _empty = true;

  void rebuild(List<Path> paths) {
    final values = <double>[];
    for (var i = 0; i < paths.length; ++i) {
      _samplePathGeometry(paths[i], _gDefaultPathSampleStep, segments: values);
    }

    _segments = Float32List.fromList(values);
    _empty = _segments.isEmpty;
    if (_empty) {
      _bounds.setEmpty();
      return;
    }

    _sampledSegmentBounds(_segments, _bounds);
    _bounds.set(
      _bounds.x1 - _radius,
      _bounds.y1 - _radius,
      _bounds.x2 + _radius,
      _bounds.y2 + _radius,
    );
  }

  void getBounds(GBounds out) => out.copyFrom(_bounds);

  double distanceSquaredTo(double x, double y, [GPoint? nearest]) =>
      _distanceSquaredToSegments(_segments, x, y, nearest);

  bool contains(double x, double y) {
    if (_empty ||
        x < _bounds.x1 ||
        y < _bounds.y1 ||
        x > _bounds.x2 ||
        y > _bounds.y2) {
      return false;
    }
    return distanceSquaredTo(x, y) <= _radiusSq;
  }
}

bool _hitTestPointerSelf(GNode node, double x, double y) {
  final area = node._pointer?._hitArea;
  return area?.contains(x, y) ?? node.hitTestLocal(x, y);
}
