part of 'package:graphx/graphx.dart';

/// Post-processes the rendered pixels of one node subtree.
///
/// Filters are local effects: they are not inherited by descendants. Assigning
/// any filter requires subtree isolation in [GCompositeMode.auto]. A filter
/// instance belongs to at most one live node at a time so mutable values can
/// request paint without listener/owner bookkeeping on every frame.
sealed class GFilter {
  WeakReference<GNode>? _owner;
  int _version = 0;

  void _attach(GNode owner) {
    final current = _owner?.target;
    if (current != null && !current.isDisposed && !identical(current, owner)) {
      throw StateError('A GFilter instance can belong to only one node.');
    }
    _owner = WeakReference<GNode>(owner);
  }

  void _detach(GNode owner) {
    if (identical(_owner?.target, owner)) _owner = null;
  }

  void _changed() {
    _version++;
    final owner = _owner?.target;
    if (owner == null || owner.isDisposed) {
      _owner = null;
      return;
    }
    owner._filterChanged();
  }

  void _expandBounds(GBounds bounds);
}

/// Gaussian blur applied to a complete node subtree.
final class GBlurFilter extends GFilter {
  GBlurFilter({double blurX = 4.0, double blurY = 4.0})
    : _blurX = _checkedBlur(blurX, 'blurX'),
      _blurY = _checkedBlur(blurY, 'blurY');

  double _blurX;
  double _blurY;

  double get blurX => _blurX;
  set blurX(double value) {
    value = _checkedBlur(value, 'blurX');
    if (_blurX == value) return;
    _blurX = value;
    _changed();
  }

  double get blurY => _blurY;
  set blurY(double value) {
    value = _checkedBlur(value, 'blurY');
    if (_blurY == value) return;
    _blurY = value;
    _changed();
  }

  void setBlur(double x, double y) {
    x = _checkedBlur(x, 'blurX');
    y = _checkedBlur(y, 'blurY');
    if (_blurX == x && _blurY == y) return;
    _blurX = x;
    _blurY = y;
    _changed();
  }

  @override
  void _expandBounds(GBounds bounds) {
    if (bounds.isEmpty) return;
    final x = _blurPadding(_blurX);
    final y = _blurPadding(_blurY);
    bounds
      ..x1 -= x
      ..y1 -= y
      ..x2 += x
      ..y2 += y;
  }
}

/// Drop shadow behind or inside a complete node subtree.
///
/// Set [inner] to keep the shadow inside the composited source alpha. The live
/// Canvas path is multi-pass by nature; `node.cache.enabled` retains the
/// finished filtered subtree and amortizes that cost when its pixels are stable.
final class GDropShadowFilter extends GFilter {
  GDropShadowFilter({
    double offsetX = 4.0,
    double offsetY = 4.0,
    double blurX = 6.0,
    double blurY = 6.0,
    ui.Color color = const ui.Color(0x80000000),
    bool inner = false,
  }) : _offsetX = _checkedFinite(offsetX, 'offsetX'),
       _offsetY = _checkedFinite(offsetY, 'offsetY'),
       _blurX = _checkedBlur(blurX, 'blurX'),
       _blurY = _checkedBlur(blurY, 'blurY'),
       _color = color,
       _inner = inner;

  double _offsetX;
  double _offsetY;
  double _blurX;
  double _blurY;
  ui.Color _color;
  bool _inner;

  double get offsetX => _offsetX;
  set offsetX(double value) {
    value = _checkedFinite(value, 'offsetX');
    if (_offsetX == value) return;
    _offsetX = value;
    _changed();
  }

  double get offsetY => _offsetY;
  set offsetY(double value) {
    value = _checkedFinite(value, 'offsetY');
    if (_offsetY == value) return;
    _offsetY = value;
    _changed();
  }

  double get blurX => _blurX;
  set blurX(double value) {
    value = _checkedBlur(value, 'blurX');
    if (_blurX == value) return;
    _blurX = value;
    _changed();
  }

  double get blurY => _blurY;
  set blurY(double value) {
    value = _checkedBlur(value, 'blurY');
    if (_blurY == value) return;
    _blurY = value;
    _changed();
  }

  ui.Color get color => _color;
  set color(ui.Color value) {
    if (_color == value) return;
    _color = value;
    _changed();
  }

  bool get inner => _inner;
  set inner(bool value) {
    if (_inner == value) return;
    _inner = value;
    _changed();
  }

  void setOffset(double x, double y) {
    x = _checkedFinite(x, 'offsetX');
    y = _checkedFinite(y, 'offsetY');
    if (_offsetX == x && _offsetY == y) return;
    _offsetX = x;
    _offsetY = y;
    _changed();
  }

  void setBlur(double x, double y) {
    x = _checkedBlur(x, 'blurX');
    y = _checkedBlur(y, 'blurY');
    if (_blurX == x && _blurY == y) return;
    _blurX = x;
    _blurY = y;
    _changed();
  }

  @override
  void _expandBounds(GBounds bounds) {
    if (_inner) return;
    _expandOuterBounds(
      bounds,
      offsetX: _offsetX,
      offsetY: _offsetY,
      blurX: _blurX,
      blurY: _blurY,
    );
  }
}

/// Colored glow around or inside a complete node subtree.
///
/// [spread] expands the silhouette for an outer glow and contracts it for
/// an inner glow before blurring. The morphology stays inside the same native
/// image-filter chain; [inner] changes only the branching/compositing semantics.
final class GGlowFilter extends GFilter {
  GGlowFilter({
    double blurX = 6.0,
    double blurY = 6.0,
    double spread = 0.0,
    ui.Color color = const ui.Color(0xffffffff),
    bool inner = false,
  }) : _blurX = _checkedBlur(blurX, 'blurX'),
       _blurY = _checkedBlur(blurY, 'blurY'),
       _spread = _checkedBlur(spread, 'spread'),
       _color = color,
       _inner = inner;

  double _blurX;
  double _blurY;
  double _spread;
  ui.Color _color;
  bool _inner;

  double get blurX => _blurX;
  set blurX(double value) {
    value = _checkedBlur(value, 'blurX');
    if (_blurX == value) return;
    _blurX = value;
    _changed();
  }

  double get blurY => _blurY;
  set blurY(double value) {
    value = _checkedBlur(value, 'blurY');
    if (_blurY == value) return;
    _blurY = value;
    _changed();
  }

  double get spread => _spread;
  set spread(double value) {
    value = _checkedBlur(value, 'spread');
    if (_spread == value) return;
    _spread = value;
    _changed();
  }

  ui.Color get color => _color;
  set color(ui.Color value) {
    if (_color == value) return;
    _color = value;
    _changed();
  }

  bool get inner => _inner;
  set inner(bool value) {
    if (_inner == value) return;
    _inner = value;
    _changed();
  }

  void setBlur(double x, double y) {
    x = _checkedBlur(x, 'blurX');
    y = _checkedBlur(y, 'blurY');
    if (_blurX == x && _blurY == y) return;
    _blurX = x;
    _blurY = y;
    _changed();
  }

  @override
  void _expandBounds(GBounds bounds) {
    if (_inner) return;
    _expandOuterBounds(
      bounds,
      blurX: _blurX,
      blurY: _blurY,
      spreadX: _spread,
      spreadY: _spread,
    );
  }
}

/// Inner bevel generated from the composited alpha of a complete node subtree.
///
/// Positive [offsetX]/[offsetY] place the highlight toward the top/left and the
/// shadow toward the bottom/right. The effect is clipped to the source alpha,
/// so it never expands effect bounds.
final class GBevelFilter extends GFilter {
  GBevelFilter({
    double offsetX = 3.0,
    double offsetY = 3.0,
    double blurX = 3.0,
    double blurY = 3.0,
    ui.Color highlightColor = const ui.Color(0x99ffffff),
    ui.Color shadowColor = const ui.Color(0x99000000),
  }) : _offsetX = _checkedFinite(offsetX, 'offsetX'),
       _offsetY = _checkedFinite(offsetY, 'offsetY'),
       _blurX = _checkedBlur(blurX, 'blurX'),
       _blurY = _checkedBlur(blurY, 'blurY'),
       _highlightColor = highlightColor,
       _shadowColor = shadowColor;

  double _offsetX;
  double _offsetY;
  double _blurX;
  double _blurY;
  ui.Color _highlightColor;
  ui.Color _shadowColor;

  double get offsetX => _offsetX;
  set offsetX(double value) {
    value = _checkedFinite(value, 'offsetX');
    if (_offsetX == value) return;
    _offsetX = value;
    _changed();
  }

  double get offsetY => _offsetY;
  set offsetY(double value) {
    value = _checkedFinite(value, 'offsetY');
    if (_offsetY == value) return;
    _offsetY = value;
    _changed();
  }

  double get blurX => _blurX;
  set blurX(double value) {
    value = _checkedBlur(value, 'blurX');
    if (_blurX == value) return;
    _blurX = value;
    _changed();
  }

  double get blurY => _blurY;
  set blurY(double value) {
    value = _checkedBlur(value, 'blurY');
    if (_blurY == value) return;
    _blurY = value;
    _changed();
  }

  ui.Color get highlightColor => _highlightColor;
  set highlightColor(ui.Color value) {
    if (_highlightColor == value) return;
    _highlightColor = value;
    _changed();
  }

  ui.Color get shadowColor => _shadowColor;
  set shadowColor(ui.Color value) {
    if (_shadowColor == value) return;
    _shadowColor = value;
    _changed();
  }

  void setOffset(double x, double y) {
    x = _checkedFinite(x, 'offsetX');
    y = _checkedFinite(y, 'offsetY');
    if (_offsetX == x && _offsetY == y) return;
    _offsetX = x;
    _offsetY = y;
    _changed();
  }

  void setBlur(double x, double y) {
    x = _checkedBlur(x, 'blurX');
    y = _checkedBlur(y, 'blurY');
    if (_blurX == x && _blurY == y) return;
    _blurX = x;
    _blurY = y;
    _changed();
  }

  @override
  void _expandBounds(GBounds bounds) {}
}

/// Colored outline around or inside a complete node subtree.
///
/// The outline is generated from the composited alpha silhouette, so it works
/// uniformly for shapes, text, images and mixed subtrees without geometry
/// knowledge. [softness] optionally blurs the expanded silhouette after native
/// morphology without adding another scene replay or saveLayer.
final class GOutlineFilter extends GFilter {
  GOutlineFilter({
    double width = 2.0,
    double softness = 0.0,
    ui.Color color = const ui.Color(0xff000000),
  }) : _width = _checkedBlur(width, 'width'),
       _softness = _checkedBlur(softness, 'softness'),
       _color = color;

  double _width;
  double _softness;
  ui.Color _color;

  double get width => _width;
  set width(double value) {
    value = _checkedBlur(value, 'width');
    if (_width == value) return;
    _width = value;
    _changed();
  }

  double get softness => _softness;
  set softness(double value) {
    value = _checkedBlur(value, 'softness');
    if (_softness == value) return;
    _softness = value;
    _changed();
  }

  ui.Color get color => _color;
  set color(ui.Color value) {
    if (_color == value) return;
    _color = value;
    _changed();
  }

  @override
  void _expandBounds(GBounds bounds) => _expandOuterBounds(
    bounds,
    blurX: _softness,
    blurY: _softness,
    spreadX: _width,
    spreadY: _width,
  );
}

/// Custom fragment-shader post effect applied to the composited subtree.
///
/// Flutter's shader image-filter path is currently available only on Impeller.
/// Check [isSupported] before assigning one when the active backend is unknown.
/// The shader must satisfy `ImageFilter.shader`: its first uniform is a vec2
/// reserved for input size and its first sampler2D receives the source image.
///
/// [padding] expands temporary effect bounds equally on every side for shaders
/// that sample outside their source rectangle.
final class GShaderFilter extends GFilter {
  GShaderFilter(this.shader, {double padding = 0.0})
    : _padding = _checkedBlur(padding, 'padding');

  static bool get isSupported => ui.ImageFilter.isShaderFilterSupported;

  final ui.FragmentShader shader;
  double _padding;

  double get padding => _padding;
  set padding(double value) {
    value = _checkedBlur(value, 'padding');
    if (_padding == value) return;
    _padding = value;
    _changed();
  }

  /// Updates one raw float uniform. Slots 0 and 1 are engine-owned input size.
  void setFloat(int index, double value) {
    if (index < 2) {
      throw ArgumentError.value(
        index,
        'index',
        '0 and 1 are reserved for input size.',
      );
    }
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    shader.setFloat(index, value);
    _changed();
  }

  /// Requests repaint after directly mutating shader uniforms or samplers.
  void invalidate() => _changed();

  @override
  void _expandBounds(GBounds bounds) {
    if (bounds.isEmpty || _padding == 0.0) return;
    bounds
      ..x1 -= _padding
      ..y1 -= _padding
      ..x2 += _padding
      ..y2 += _padding;
  }
}

/// Arbitrary 4x5 RGBA color matrix applied to the composited subtree.
///
/// Unlike [GColorTransform], every output channel may depend on every input
/// channel. The supplied list is copied, so later caller mutation is ignored;
/// assign [matrix] again to update the filter.
final class GColorMatrixFilter extends GFilter {
  GColorMatrixFilter([List<double> matrix = identity])
    : _matrix = _copyColorMatrix(matrix);

  static const List<double> identity = <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> _matrix;

  List<double> get matrix => _matrix;
  set matrix(List<double> value) {
    final next = _copyColorMatrix(value);
    if (_sameColorMatrix(_matrix, next)) return;
    _matrix = next;
    _changed();
  }

  @override
  void _expandBounds(GBounds bounds) {}
}

extension GNodeFilterInspection on GNode {
  /// Returns the rendered subtree extent after nested filters in this node's
  /// local coordinate space.
  ///
  /// This is an inspection/tooling query. It does not change [localBounds],
  /// pointer hit testing, or compositor state. Filter expansion is applied in
  /// hierarchy order: a child's effect expands in child space, the result is
  /// transformed into its parent, then parent filters expand the combined
  /// subtree. Hidden/inactive descendants are excluded just like rendering.
  GBounds getEffectBounds([GBounds? out]) {
    final result = out ?? GBounds.empty();
    _computeInspectionEffectBounds(this, result, <GBounds>[], 0);
    return result;
  }
}

void _computeInspectionEffectBounds(
  GNode node,
  GBounds out,
  List<GBounds> scratch,
  int depth,
) {
  out.copyFrom(node._ensureSelfBounds());
  final children = node._children;
  if (children != null) {
    for (var i = 0; i < children.length; ++i) {
      final child = children[i];
      if (!child.active || !child._visible) continue;
      while (scratch.length <= depth) {
        scratch.add(GBounds.empty());
      }
      final childBounds = scratch[depth];
      _computeInspectionEffectBounds(child, childBounds, scratch, depth + 1);
      if (childBounds.isEmpty) continue;
      if (child.hasLocalTransform) {
        _includeFilterTransformedBounds(out, childBounds, child.localMatrix);
      } else {
        out.includeBounds(childBounds);
      }
    }
  }

  final filters = node._composite?.filters;
  if (filters == null) return;
  for (var i = 0; i < filters.length; ++i) {
    filters[i]._expandBounds(out);
  }
}

void _includeFilterTransformedBounds(GBounds out, GBounds input, GMatrix2 m) {
  final x1 = input.x1;
  final y1 = input.y1;
  final x2 = input.x2;
  final y2 = input.y2;
  out
    ..includePoint(m.a * x1 + m.c * y1 + m.tx, m.b * x1 + m.d * y1 + m.ty)
    ..includePoint(m.a * x2 + m.c * y1 + m.tx, m.b * x2 + m.d * y1 + m.ty)
    ..includePoint(m.a * x1 + m.c * y2 + m.tx, m.b * x1 + m.d * y2 + m.ty)
    ..includePoint(m.a * x2 + m.c * y2 + m.tx, m.b * x2 + m.d * y2 + m.ty);
}

void _expandOuterBounds(
  GBounds bounds, {
  double offsetX = 0.0,
  double offsetY = 0.0,
  double blurX = 0.0,
  double blurY = 0.0,
  double spreadX = 0.0,
  double spreadY = 0.0,
}) {
  if (bounds.isEmpty) return;
  final x1 = bounds.x1;
  final y1 = bounds.y1;
  final x2 = bounds.x2;
  final y2 = bounds.y2;
  final px = spreadX + _blurPadding(blurX);
  final py = spreadY + _blurPadding(blurY);
  bounds
    ..x1 = math.min(x1, x1 + offsetX - px)
    ..y1 = math.min(y1, y1 + offsetY - py)
    ..x2 = math.max(x2, x2 + offsetX + px)
    ..y2 = math.max(y2, y2 + offsetY + py);
}

double _checkedBlur(double value, String name) {
  value = _checkedFinite(value, name);
  if (value < 0.0) {
    throw ArgumentError.value(value, name, 'must be >= 0');
  }
  return value;
}

double _checkedFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'must be finite');
  }
  return value;
}

double _blurPadding(double sigma) => sigma * 3.0;

List<double> _copyColorMatrix(List<double> value) {
  if (value.length != 20) {
    throw ArgumentError.value(value.length, 'matrix.length', 'must be 20');
  }
  final copy = List<double>.of(value, growable: false);
  for (var i = 0; i < copy.length; ++i) {
    if (!copy[i].isFinite) {
      throw ArgumentError.value(copy[i], 'matrix[$i]', 'must be finite');
    }
  }
  return List<double>.unmodifiable(copy);
}

bool _sameColorMatrix(List<double> a, List<double> b) {
  for (var i = 0; i < 20; ++i) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
