part of 'package:graphx/graphx.dart';

/// Orientation used when stamping a [GLinePattern] along a source path.
enum GLinePatternAlignment {
  /// Rotate each motif so its authored forward axis follows path direction.
  tangent,

  /// Keep motif orientation fixed in the source path's local coordinate space.
  fixed,
}

/// Small reusable vector motif for [GGraphics.linePattern].
///
/// The input [Path] is copied at construction. [pivot] is the motif-local point
/// placed on the sampled source path. [rotation] is an authored orientation
/// offset applied before placement, so tangent alignment does not require motif
/// paths to be authored with +X as their natural forward direction.
///
/// [phase] is retained mutable state: changing it invalidates only generated
/// motif geometry and requests repaint on graphics using this pattern. Source
/// paths and their cached [ui.PathMetric] snapshots remain untouched.
final class GLinePattern {
  GLinePattern(
    Path path, {
    required this.advance,
    this.alignment = GLinePatternAlignment.tangent,
    this.filled = false,
    GPoint? pivot,
    this.rotation = 0.0,
    double phase = 0.0,
  }) : _path = Path.from(path),
       _pivotX = pivot?.x ?? 0.0,
       _pivotY = pivot?.y ?? 0.0,
       _phase = phase {
    if (!advance.isFinite || advance <= 0.0) {
      throw ArgumentError.value(advance, 'advance', 'Must be finite and > 0.');
    }
    if (!_pivotX.isFinite || !_pivotY.isFinite) {
      throw ArgumentError.value(pivot, 'pivot', 'Coordinates must be finite.');
    }
    if (!rotation.isFinite) {
      throw ArgumentError.value(rotation, 'rotation', 'Must be finite.');
    }
    if (!phase.isFinite) {
      throw ArgumentError.value(phase, 'phase', 'Must be finite.');
    }

    final bounds = _path.getBounds();
    final left = bounds.left - _pivotX;
    final top = bounds.top - _pivotY;
    final right = bounds.right - _pivotX;
    final bottom = bounds.bottom - _pivotY;

    _motifRadius = math.sqrt(
      math.max(
        math.max(left * left + top * top, right * right + top * top),
        math.max(
          left * left + bottom * bottom,
          right * right + bottom * bottom,
        ),
      ),
    );

    final c = math.cos(rotation);
    final s = math.sin(rotation);
    final x0 = c * left - s * top;
    final y0 = s * left + c * top;
    final x1 = c * right - s * top;
    final y1 = s * right + c * top;
    final x2 = c * left - s * bottom;
    final y2 = s * left + c * bottom;
    final x3 = c * right - s * bottom;
    final y3 = s * right + c * bottom;
    _motifBounds = Rect.fromLTRB(
      math.min(math.min(x0, x1), math.min(x2, x3)),
      math.min(math.min(y0, y1), math.min(y2, y3)),
      math.max(math.max(x0, x1), math.max(x2, x3)),
      math.max(math.max(y0, y1), math.max(y2, y3)),
    );
  }

  final Path _path;
  final double _pivotX;
  final double _pivotY;
  late final Rect _motifBounds;
  late final double _motifRadius;
  final List<WeakReference<GGraphics>> _graphics = <WeakReference<GGraphics>>[];
  int _phaseVersion = 0;
  double _phase;

  /// Desired distance in source-path local units between motif anchors.
  ///
  /// Open contours use this distance exactly. Closed contours choose the
  /// nearest integral motif count and fit spacing uniformly around the loop so
  /// phase animation has no disappearing/duplicated seam motif.
  final double advance;

  final GLinePatternAlignment alignment;

  /// Paints the generated motif path as a fill using the active line brush.
  final bool filled;

  /// Motif-local point placed exactly on each sampled source-path position.
  ///
  /// The supplied point is copied at construction.
  GPoint get pivot => GPoint(_pivotX, _pivotY);

  /// Additional motif rotation in radians.
  ///
  /// For [GLinePatternAlignment.tangent], the effective orientation is the
  /// source tangent angle plus this value. For fixed alignment, this is the
  /// complete motif orientation.
  final double rotation;

  /// Shared retained phase in source-path local units.
  ///
  /// Increasing phase moves motifs forward along increasing path distance.
  /// A per-use offset may additionally be supplied to [GGraphics.linePattern].
  double get phase => _phase;
  set phase(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'phase', 'Must be finite.');
    }
    if (value == _phase) return;
    _phase = value;
    _phaseVersion++;
    for (var i = _graphics.length - 1; i >= 0; --i) {
      final graphics = _graphics[i].target;
      if (graphics == null) {
        _graphics.removeAt(i);
      } else {
        graphics._onPaintChanged();
      }
    }
  }

  void _watch(GGraphics graphics) {
    for (var i = 0; i < _graphics.length; ++i) {
      if (identical(_graphics[i].target, graphics)) return;
    }
    _graphics.add(WeakReference<GGraphics>(graphics));
  }
}

sealed class _GLineGeometry {
  const _GLineGeometry(this.phase);

  /// Per-use phase offset retained in the stroke batch.
  final double phase;

  bool get paintAsFill => false;
  int get decorationVersion => 0;

  /// Phase-independent conservative generated bounds when available.
  Rect? conservativeBounds(Rect sourceBounds) => null;

  bool build(List<ui.PathMetric> metrics, Path target);
}

final class _GDashLineGeometry extends _GLineGeometry {
  _GDashLineGeometry(List<double> values, double phase)
    : values = List<double>.unmodifiable(_normalizeDash(values)),
      super(phase);

  final List<double> values;

  @override
  bool build(List<ui.PathMetric> metrics, Path target) {
    var cycle = 0.0;
    for (var i = 0; i < values.length; ++i) {
      cycle += values[i];
    }
    if (cycle == 0.0) return false;

    var emitted = false;
    for (final metric in metrics) {
      final length = metric.length;
      if (length <= 0.0) continue;

      // Positive phase moves painted geometry forward along the contour.
      var patternOffset = _positiveModulo(-phase, cycle);
      var index = 0;
      while (patternOffset >= values[index]) {
        patternOffset -= values[index];
        index = (index + 1) % values.length;
      }

      var distance = 0.0;
      var remaining = values[index] - patternOffset;
      while (distance < length) {
        final end = math.min(length, distance + remaining);
        if (index.isEven && end > distance) {
          target.addPath(metric.extractPath(distance, end), Offset.zero);
          emitted = true;
        }
        distance = end;
        index = (index + 1) % values.length;
        remaining = values[index];
      }
    }
    return emitted;
  }
}

final class _GPatternLineGeometry extends _GLineGeometry {
  const _GPatternLineGeometry(this.pattern, double phase) : super(phase);

  final GLinePattern pattern;

  @override
  bool get paintAsFill => pattern.filled;

  @override
  int get decorationVersion => pattern._phaseVersion;

  @override
  Rect conservativeBounds(Rect sourceBounds) {
    if (pattern.alignment == GLinePatternAlignment.fixed) {
      final motif = pattern._motifBounds;
      return Rect.fromLTRB(
        sourceBounds.left + motif.left,
        sourceBounds.top + motif.top,
        sourceBounds.right + motif.right,
        sourceBounds.bottom + motif.bottom,
      );
    }
    return sourceBounds.inflate(pattern._motifRadius);
  }

  @override
  bool build(List<ui.PathMetric> metrics, Path target) {
    final matrix = Float64List(16);
    matrix[10] = 1.0;
    matrix[15] = 1.0;
    var emitted = false;
    final effectivePhase = pattern.phase + phase;

    for (final metric in metrics) {
      final length = metric.length;
      if (length <= 0.0) continue;

      final count = metric.isClosed
          ? math.max(1, (length / pattern.advance).round())
          : 0;
      final step = metric.isClosed ? length / count : pattern.advance;
      var distance = _positiveModulo(effectivePhase, step);
      final limit = metric.isClosed ? count : 0x7fffffff;

      for (var i = 0; i < limit && distance < length; ++i) {
        final tangent = _patternTangent(metric, distance, step);
        if (tangent != null) {
          // dart:ui Tangent.angle intentionally flips the vector angle to match
          // Path.arcTo sweep semantics. Path transforms use the vector-space
          // rotation sign, so negate it again before stamping the motif.
          final baseAngle = pattern.alignment == GLinePatternAlignment.tangent
              ? -tangent.angle
              : 0.0;
          final angle = baseAngle + pattern.rotation;
          final c = math.cos(angle);
          final s = math.sin(angle);
          final px = pattern._pivotX;
          final py = pattern._pivotY;
          final pivotX = c * px - s * py;
          final pivotY = s * px + c * py;
          matrix
            ..[0] = c
            ..[1] = s
            ..[2] = 0.0
            ..[3] = 0.0
            ..[4] = -s
            ..[5] = c
            ..[6] = 0.0
            ..[7] = 0.0
            ..[8] = 0.0
            ..[9] = 0.0
            ..[11] = 0.0
            ..[12] = tangent.position.dx - pivotX
            ..[13] = tangent.position.dy - pivotY
            ..[14] = 0.0;
          target.addPath(pattern._path, Offset.zero, matrix4: matrix);
          emitted = true;
        }
        distance += step;
      }
    }
    return emitted;
  }
}

ui.Tangent? _patternTangent(
  ui.PathMetric metric,
  double distance,
  double step,
) {
  final tangent = metric.getTangentForOffset(distance);
  if (tangent == null || !metric.isClosed) return tangent;

  // A closed contour has no visual seam, but PathMetric still has a start/end
  // parameter boundary. Sampling a short chord across the anchor makes the
  // orientation continuous through that seam and also avoids one-frame tangent
  // spikes at sharp/boolean-generated vertices. Open contours stay on the fast
  // single-tangent path.
  final radius = math.min(step * .125, 4.0);
  final length = metric.length;
  if (radius <= 0.0 || length <= radius * 2.0) return tangent;

  final before = metric.getTangentForOffset(
    _positiveModulo(distance - radius, length),
  );
  final after = metric.getTangentForOffset(
    _positiveModulo(distance + radius, length),
  );
  if (before == null || after == null) return tangent;

  final dx = after.position.dx - before.position.dx;
  final dy = after.position.dy - before.position.dy;
  if (dx * dx + dy * dy <= 1e-12) return tangent;
  return ui.Tangent(tangent.position, Offset(dx, dy));
}

List<double> _normalizeDash(List<double> values) {
  if (values.isEmpty) return const <double>[];
  for (var i = 0; i < values.length; ++i) {
    final value = values[i];
    if (!value.isFinite || value <= 0.0) {
      throw ArgumentError.value(
        values,
        'pattern',
        'Dash values must be finite and > 0.',
      );
    }
  }
  if (values.length.isEven) return values;
  return <double>[...values, ...values];
}

double _positiveModulo(double value, double divisor) {
  final result = value % divisor;
  return result < 0.0 ? result + divisor : result;
}

extension GGraphicsLinePattern on GGraphics {
  /// Applies a retained dash pattern to subsequent stroked geometry.
  ///
  /// Values alternate painted/gap lengths in local path units. Odd-length
  /// lists repeat once to form an even cycle. `null` or an empty list restores
  /// the normal solid stroke. Increasing phase moves the visible dash pattern
  /// forward along increasing contour distance.
  GGraphics lineDash(List<double>? pattern, {double phase = 0.0}) {
    if (!phase.isFinite) {
      throw ArgumentError.value(phase, 'phase', 'Must be finite.');
    }
    final stroke = _stroke;
    if (stroke == null) {
      throw StateError('lineDash() requires lineStyle() first.');
    }
    _closeBatch();
    _stroke = pattern == null || pattern.isEmpty
        ? stroke.copyWith(clearGeometry: true)
        : stroke.copyWith(geometry: _GDashLineGeometry(pattern, phase));
    return this;
  }

  /// Stamps a small vector motif along subsequent stroked geometry.
  ///
  /// [phase] is a per-use offset added to [GLinePattern.phase]. Increasing the
  /// effective phase moves motif anchors forward along increasing contour
  /// distance. Repetition restarts for each contour. Closed contours fit the
  /// nearest integral motif count around their circumference, keeping animated
  /// phase continuous without a duplicate/disappearing seam motif.
  GGraphics linePattern(GLinePattern? pattern, {double phase = 0.0}) {
    if (!phase.isFinite) {
      throw ArgumentError.value(phase, 'phase', 'Must be finite.');
    }
    final stroke = _stroke;
    if (stroke == null) {
      throw StateError('linePattern() requires lineStyle() first.');
    }
    _closeBatch();
    if (pattern == null) {
      _stroke = stroke.copyWith(clearGeometry: true);
    } else {
      pattern._watch(this);
      _stroke = stroke.copyWith(
        geometry: _GPatternLineGeometry(pattern, phase),
      );
    }
    return this;
  }
}

final class _GGraphicsBatch {
  _GGraphicsBatch({required this.fill, required this.stroke});

  final Path path = Path();
  final _GGraphicsBrush? fill;
  final _GGraphicsStroke? stroke;

  int geometryVersion = 0;
  int fillShaderVersion = -1;
  int strokeShaderVersion = -1;
  int _pathBoundsVersion = -1;
  int _pathMetricsVersion = -1;
  int _strokePathGeometryVersion = -1;
  int _strokePathDecorationVersion = -1;
  Rect _pathBounds = Rect.zero;
  Rect _strokePathBounds = Rect.zero;
  List<ui.PathMetric>? _pathMetrics;
  Path? _strokePath;
  bool _strokePathHasGeometry = false;
  ui.Shader? _fillShader;
  ui.Shader? _strokeShader;

  Rect get pathBounds {
    if (_pathBoundsVersion != geometryVersion) {
      _pathBounds = path.getBounds();
      _pathBoundsVersion = geometryVersion;
    }
    return _pathBounds;
  }

  List<ui.PathMetric> get pathMetrics {
    if (_pathMetricsVersion != geometryVersion) {
      _pathMetrics = path.computeMetrics().toList(growable: false);
      _pathMetricsVersion = geometryVersion;
    }
    return _pathMetrics!;
  }

  Path get strokePath {
    final geometry = stroke?.geometry;
    if (geometry == null) return path;
    final decorationVersion = geometry.decorationVersion;
    if (_strokePathGeometryVersion != geometryVersion ||
        _strokePathDecorationVersion != decorationVersion) {
      final derived = Path();
      _strokePathHasGeometry = geometry.build(pathMetrics, derived);
      _strokePath = derived;
      _strokePathBounds = _strokePathHasGeometry
          ? derived.getBounds()
          : Rect.zero;
      _strokePathGeometryVersion = geometryVersion;
      _strokePathDecorationVersion = decorationVersion;
    }
    return _strokePath!;
  }

  bool get strokePathHasGeometry {
    if (stroke?.geometry == null) return true;
    strokePath;
    return _strokePathHasGeometry;
  }

  bool get strokePathPaintAsFill => stroke?.geometry?.paintAsFill ?? false;

  Rect get strokePathBounds {
    final geometry = stroke?.geometry;
    if (geometry == null) return pathBounds;
    final conservative = geometry.conservativeBounds(pathBounds);
    if (conservative != null) return conservative;
    strokePath;
    return _strokePathBounds;
  }

  ui.Shader? get fillShader => _fillShader;
  set fillShader(ui.Shader? value) {
    if (identical(_fillShader, value)) return;
    final old = _fillShader;
    _fillShader = value;
    if (old != null && !identical(old, _strokeShader)) old.dispose();
  }

  ui.Shader? get strokeShader => _strokeShader;
  set strokeShader(ui.Shader? value) {
    if (identical(_strokeShader, value)) return;
    final old = _strokeShader;
    _strokeShader = value;
    if (old != null && !identical(old, _fillShader)) old.dispose();
  }

  bool get paints => fill != null || stroke != null;

  void disposeGeneratedShaders() {
    final fill = _fillShader;
    final stroke = _strokeShader;
    _fillShader = null;
    _strokeShader = null;
    if (fill != null) fill.dispose();
    if (stroke != null && !identical(stroke, fill)) stroke.dispose();
  }
}
