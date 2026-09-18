part of 'package:graphx/graphx.dart';

/// Controls whether a node subtree is drawn directly or isolated first.
enum GCompositeMode {
  /// Let GraphX choose the cheapest correct path.
  auto,

  /// Draw directly into the current target. Features that require isolation
  /// assert in debug mode rather than silently changing semantics.
  direct,

  /// Isolate this node and its descendants with Canvas.saveLayer().
  layer,
}

/// Controls how a mask node affects its target subtree.
enum GMaskMode {
  /// Keep pixels covered by the mask alpha.
  alpha,

  /// Keep pixels outside the mask alpha.
  alphaInverse,
}

/// Cheap local-space clipping applied to a node's visual and descendants.
abstract interface class GClip {
  void _apply(Canvas canvas, GNode owner);

  factory GClip.rect(double x, double y, double width, double height) =
      GRectClip;

  factory GClip.roundRect(
    double x,
    double y,
    double width,
    double height,
    double radius,
  ) = GRoundRectClip;

  factory GClip.path(Path path) = GPathClip;

  /// Keeps the owner's local bounds except where [path] overlaps them.
  ///
  /// The owner's canonical local bounds are resolved lazily. The retained
  /// even-odd clip path is rebuilt only when those bounds change.
  factory GClip.inversePath(Path path) = GInversePathClip;
}

final class GRectClip implements GClip {
  GRectClip(double x, double y, double width, double height)
    : rect = Rect.fromLTWH(x, y, width, height);

  final Rect rect;

  @override
  void _apply(Canvas canvas, GNode owner) {
    canvas.clipRect(rect);
  }
}

final class GRoundRectClip implements GClip {
  GRoundRectClip(double x, double y, double width, double height, double radius)
    : rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        Radius.circular(radius),
      );

  final RRect rrect;

  @override
  void _apply(Canvas canvas, GNode owner) {
    canvas.clipRRect(rrect);
  }
}

final class GPathClip implements GClip {
  GPathClip(Path path) : path = Path.from(path);

  final Path path;

  @override
  void _apply(Canvas canvas, GNode owner) {
    canvas.clipPath(path);
  }
}

final class GInversePathClip implements GClip {
  GInversePathClip(Path path) : _hole = Path.from(path);

  final Path _hole;
  final Path _path = Path()..fillType = PathFillType.evenOdd;
  double _x1 = double.nan;
  double _y1 = double.nan;
  double _x2 = double.nan;
  double _y2 = double.nan;

  @override
  void _apply(Canvas canvas, GNode owner) {
    final bounds = owner._ensureLocalBounds();
    if (bounds.isEmpty) {
      canvas.clipRect(Rect.zero);
      return;
    }

    if (_x1 != bounds.x1 ||
        _y1 != bounds.y1 ||
        _x2 != bounds.x2 ||
        _y2 != bounds.y2) {
      _x1 = bounds.x1;
      _y1 = bounds.y1;
      _x2 = bounds.x2;
      _y2 = bounds.y2;
      _path
        ..reset()
        ..fillType = PathFillType.evenOdd
        ..addRect(Rect.fromLTRB(_x1, _y1, _x2, _y2))
        ..addPath(_hole, Offset.zero);
    }

    canvas.clipPath(_path);
  }
}

extension GNodeCompositing on GNode {
  /// Local-space clip applied to this node's visual and descendants.
  ///
  /// Clipping is direct and does not create an offscreen layer. Pointer
  /// interaction respects the same clip geometry.
  GClip? get clip => _composite?.clip;
  set clip(GClip? value) {
    if (identical(clip, value)) return;
    final state = _composite ??= _GNodeComposite();
    state.clip = value;
    _trimCompositeState();
    invalidatePaint();
    invalidateInteractionGeometry();
  }

  /// Alpha mask for this node's visual and descendants.
  ///
  /// A mask is a normal scene node whose rendered alpha becomes coverage. An
  /// active mask source is not drawn in the normal scene pass. Masks require
  /// isolation and therefore cannot be combined with [GCompositeMode.direct].
  GNode? get mask => _composite?.mask;
  set mask(GNode? value) {
    if (identical(mask, value)) return;
    if (identical(value, this)) {
      throw ArgumentError('A node cannot mask itself.');
    }
    final old = _composite?.mask;
    if (old != null) _releaseMaskSource(old, this);
    if (value != null) _retainMaskSource(value, this);
    final state = _composite ??= _GNodeComposite();
    state.mask = value;
    _trimCompositeState();
    invalidatePaint();
  }

  /// Controls whether [mask] keeps its covered or uncovered pixels.
  GMaskMode get maskMode => _composite?.maskMode ?? GMaskMode.alpha;
  set maskMode(GMaskMode value) {
    if (maskMode == value) return;
    final state = _composite ??= _GNodeComposite();
    state.maskMode = value;
    _trimCompositeState();
    invalidatePaint();
  }

  /// Ordered post-processing effects for this node's complete rendered subtree.
  ///
  /// Filters are local rather than inherited. They do not change canonical
  /// node bounds or pointer hit testing; the compositor expands only its
  /// temporary effect bounds. Assigning any filter makes [GCompositeMode.auto]
  /// isolate the subtree and conflicts with [GCompositeMode.direct].
  List<GFilter> get filters => _composite?.filters ?? const <GFilter>[];
  set filters(List<GFilter> value) {
    final old = _composite?.filters;
    if (_sameFilterList(old, value)) return;

    for (var i = 0; i < value.length; ++i) {
      final owner = value[i]._owner?.target;
      if (owner != null && !owner.isDisposed && !identical(owner, this)) {
        throw StateError('A GFilter instance can belong to only one node.');
      }
    }
    if (old != null) {
      for (var i = 0; i < old.length; ++i) {
        old[i]._detach(this);
      }
    }

    if (value.isEmpty) {
      final state = _composite;
      if (state == null) return;
      state
        ..filters = null
        .._filtersChanged();
      _trimCompositeState();
      invalidatePaint();
      return;
    }

    final next = List<GFilter>.unmodifiable(value);
    for (var i = 0; i < next.length; ++i) {
      next[i]._attach(this);
    }
    final state = _composite ??= _GNodeComposite();
    state
      ..filters = next
      .._filtersChanged();
    invalidatePaint();
  }

  void _filterChanged() {
    final state = _composite;
    if (state?.filters == null) return;
    state!._filtersChanged();
    invalidatePaint();
  }

  void _trimCompositeState() {
    final state = _composite;
    if (state != null && state.isDefault) _composite = null;
  }
}

bool _sameFilterList(List<GFilter>? a, List<GFilter> b) {
  if (a == null) return b.isEmpty;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; ++i) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

void _retainMaskSource(GNode source, GNode target) {
  final state = source._composite ??= _GNodeComposite();
  (state.maskTargets ??= <GNode>{}).add(target);
  source.invalidatePaint();
}

void _releaseMaskSource(GNode source, GNode target) {
  final state = source._composite;
  final targets = state?.maskTargets;
  if (state == null || targets == null) return;
  targets.remove(target);
  if (targets.isEmpty) state.maskTargets = null;
  if (state.isDefault) source._composite = null;
  source.invalidatePaint();
}

bool _isActiveMaskSource(GNode source) {
  final state = source._composite;
  final targets = state?.maskTargets;
  if (state == null || targets == null) return false;
  targets.removeWhere(
    (target) =>
        target.isDisposed || !identical(target._composite?.mask, source),
  );
  if (targets.isNotEmpty) return true;
  state.maskTargets = null;
  if (state.isDefault) source._composite = null;
  return false;
}

final class _GNodeComposite {
  GCompositeMode mode = GCompositeMode.auto;
  ui.BlendMode blendMode = ui.BlendMode.srcOver;
  GClip? clip;
  GNode? mask;
  GMaskMode maskMode = GMaskMode.alpha;
  Set<GNode>? maskTargets;
  _GNodeColorTransform? colorTransform;
  List<GFilter>? filters;

  int filterVersion = 0;
  bool hasBranchingFilter = false;
  bool filterAffectsTransparentBlack = false;

  void _filtersChanged() {
    filterVersion++;
    hasBranchingFilter = false;
    filterAffectsTransparentBlack = false;
    final values = filters;
    if (values == null) return;
    for (var i = 0; i < values.length; ++i) {
      final filter = values[i];
      if (filter is GDropShadowFilter ||
          filter is GGlowFilter ||
          filter is GOutlineFilter ||
          filter is GBevelFilter) {
        hasBranchingFilter = true;
      } else if (filter is GColorMatrixFilter && filter.matrix[19] > 0.0) {
        filterAffectsTransparentBlack = true;
      }
    }
  }

  bool get autoRequiresLayer =>
      mask != null || blendMode != ui.BlendMode.srcOver || filters != null;

  bool get requiresLayer =>
      mode == GCompositeMode.layer ||
      (mode == GCompositeMode.auto && autoRequiresLayer);

  bool get directConflict => mode == GCompositeMode.direct && autoRequiresLayer;

  bool get isDefault =>
      mode == GCompositeMode.auto &&
      blendMode == ui.BlendMode.srcOver &&
      clip == null &&
      mask == null &&
      maskMode == GMaskMode.alpha &&
      maskTargets == null &&
      colorTransform == null &&
      filters == null;
}
