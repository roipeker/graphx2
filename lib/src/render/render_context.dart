part of 'package:graphx/src/graphx_impl.dart';

class GRenderContext implements _GDisposable {
  late Canvas canvas;
  GStage? _stage;
  GRenderStats? _renderStats;
  double alpha = 1.0;

  /// Stage associated with the current render pass.
  ///
  /// Detached offscreen captures have no Stage and therefore cannot expose one.
  /// Canvas-node painters that require Stage state are inherently hosted-only.
  GStage get stage =>
      _stage ?? (throw StateError('Render context has no associated Stage.'));

  final _opacityPaint = Paint();
  final _transform = Float64List.fromList([
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
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  Float64List _colorStack = Float64List(64);
  int _colorDepth = 0;
  int _colorVersion = 0;
  double _redMultiplier = 1.0;
  double _greenMultiplier = 1.0;
  double _blueMultiplier = 1.0;
  double _alphaMultiplier = 1.0;
  double _redOffset = 0.0;
  double _greenOffset = 0.0;
  double _blueOffset = 0.0;
  double _alphaOffset = 0.0;
  bool _hasColorTransform = false;
  GColorTransform? _colorSnapshot;
  ColorFilter? _colorFilter;
  int _colorFilterVersion = -1;
  double _colorFilterAlpha = double.nan;

  bool get hasColorTransform => _hasColorTransform;

  GColorTransform get colorTransform {
    if (!_hasColorTransform) return GColorTransform.identity;
    return _colorSnapshot ??= GColorTransform(
      redMultiplier: _redMultiplier,
      greenMultiplier: _greenMultiplier,
      blueMultiplier: _blueMultiplier,
      alphaMultiplier: _alphaMultiplier,
      redOffset: _redOffset,
      greenOffset: _greenOffset,
      blueOffset: _blueOffset,
      alphaOffset: _alphaOffset,
    );
  }

  void begin(Canvas canvas, GStage stage) {
    _begin(canvas, stage, stage._activeStats?.render);
  }

  /// Starts an auxiliary render pass that does not participate in hosted
  /// diagnostics. [sourceStage] is carried only to preserve Stage access for an
  /// attached source; detached captures pass null and remain fully stage-free.
  void _beginOffscreen(Canvas canvas, GStage? sourceStage) {
    _begin(canvas, sourceStage, null);
  }

  void _begin(Canvas canvas, GStage? stage, GRenderStats? renderStats) {
    this.canvas = canvas;
    _stage = stage;
    _renderStats = renderStats;
    alpha = 1.0;
    _colorDepth = 0;
    _setIdentityColor();
  }

  void end() {
    _stage = null;
    _renderStats = null;
  }

  void transform(GMatrix2 m) {
    final v = _transform;
    v[0] = m.a;
    v[1] = m.b;
    v[4] = m.c;
    v[5] = m.d;
    v[12] = m.tx;
    v[13] = m.ty;
    canvas.transform(v);
  }

  /// Bounded fallback opacity for renderables that cannot apply [alpha]
  /// directly to their primitive paints.
  void saveOpacityLayer(ui.Rect bounds, double alpha) {
    assert(alpha >= 0.0 && alpha <= 1.0);
    _opacityPaint
      ..color = ui.Color.fromARGB(
        (alpha * 255.0).round().clamp(0, 255).toInt(),
        255,
        255,
        255,
      )
      ..colorFilter = null
      ..imageFilter = null
      ..blendMode = ui.BlendMode.srcOver;
    _saveLayer(bounds, _opacityPaint);
  }

  /// Fallback for renderables that cannot consume inherited paint state
  /// directly. Alpha and color transform are applied together once.
  ///
  /// Returns whether this layer needed the web alpha-offset clip workaround;
  /// pass the value to [restoreRenderStateLayer].
  bool saveRenderStateLayer(
    ui.Rect bounds, {
    ui.BlendMode blendMode = ui.BlendMode.srcOver,
    ui.ImageFilter? imageFilter,
  }) {
    assert(
      alpha < 1.0 ||
          _hasColorTransform ||
          blendMode != ui.BlendMode.srcOver ||
          imageFilter != null,
    );
    if (_hasColorTransform) {
      _opacityPaint
        ..color = const ui.Color(0xffffffff)
        ..colorFilter = _effectiveColorFilter
        ..blendMode = blendMode;
    } else {
      _opacityPaint
        ..color = ui.Color.fromARGB(
          (alpha * 255.0).round().clamp(0, 255).toInt(),
          255,
          255,
          255,
        )
        ..colorFilter = null
        ..blendMode = blendMode;
    }

    _opacityPaint.imageFilter = imageFilter;

    // TODO(graphx): CanvasKit/Skia intentionally allows a saveLayer restore
    // color filter that affects transparent black (AO > 0) to produce output
    // beyond the supplied layer bounds. GraphX clips only this web fallback
    // case to preserve display-object bounds semantics. Re-test/remove once
    // Impeller web is stable and its restore behavior is verified.
    final clipForAlphaOffset =
        kIsWeb && _hasColorTransform && _alphaOffset > 0.0;
    if (clipForAlphaOffset) {
      _renderStats?.canvasSaves.increment();
      canvas.save();
      canvas.clipRect(bounds);
    }
    _saveLayer(bounds, _opacityPaint);
    return clipForAlphaOffset;
  }

  /// Restores an opacity-only layer opened through this render context.
  void restoreLayer() => canvas.restore();

  /// Restores a render-state layer and its narrowly-scoped AO workaround.
  void restoreRenderStateLayer(bool clippedForAlphaOffset) {
    canvas.restore();
    if (clippedForAlphaOffset) canvas.restore();
  }

  void _saveLayer(ui.Rect? bounds, Paint paint) {
    _renderStats?.saveLayers.increment();
    canvas.saveLayer(bounds, paint);
  }

  ColorFilter get _effectiveColorFilter {
    final cached = _colorFilter;
    if (cached != null &&
        _colorFilterVersion == _colorVersion &&
        _colorFilterAlpha == alpha) {
      return cached;
    }

    final effectiveAlpha = alpha;
    _colorFilterVersion = _colorVersion;
    _colorFilterAlpha = effectiveAlpha;
    return _colorFilter = ColorFilter.matrix(<double>[
      _redMultiplier,
      0,
      0,
      0,
      _redOffset,
      0,
      _greenMultiplier,
      0,
      0,
      _greenOffset,
      0,
      0,
      _blueMultiplier,
      0,
      _blueOffset,
      0,
      0,
      0,
      _alphaMultiplier * effectiveAlpha,
      _alphaOffset * effectiveAlpha,
    ]);
  }

  void _pushColorTransform(_GNodeColorTransform local) {
    _saveColorState();

    final prm = _redMultiplier;
    final pgm = _greenMultiplier;
    final pbm = _blueMultiplier;
    final pam = _alphaMultiplier;
    _redMultiplier = prm * local.redMultiplier;
    _greenMultiplier = pgm * local.greenMultiplier;
    _blueMultiplier = pbm * local.blueMultiplier;
    _alphaMultiplier = pam * local.alphaMultiplier;
    _redOffset = prm * local.redOffset + _redOffset;
    _greenOffset = pgm * local.greenOffset + _greenOffset;
    _blueOffset = pbm * local.blueOffset + _blueOffset;
    _alphaOffset = pam * local.alphaOffset + _alphaOffset;
    _colorChanged();
  }

  void _pushIdentityColor() {
    _saveColorState();
    _setIdentityColor();
  }

  void _saveColorState() {
    final base = _colorDepth * 8;
    if (base + 8 > _colorStack.length) {
      final next = Float64List(_colorStack.length * 2);
      next.setRange(0, _colorStack.length, _colorStack);
      _colorStack = next;
    }
    final stack = _colorStack;
    stack[base] = _redMultiplier;
    stack[base + 1] = _greenMultiplier;
    stack[base + 2] = _blueMultiplier;
    stack[base + 3] = _alphaMultiplier;
    stack[base + 4] = _redOffset;
    stack[base + 5] = _greenOffset;
    stack[base + 6] = _blueOffset;
    stack[base + 7] = _alphaOffset;
    _colorDepth++;
  }

  void _popColorTransform() {
    assert(_colorDepth > 0);
    final base = --_colorDepth * 8;
    final stack = _colorStack;
    _redMultiplier = stack[base];
    _greenMultiplier = stack[base + 1];
    _blueMultiplier = stack[base + 2];
    _alphaMultiplier = stack[base + 3];
    _redOffset = stack[base + 4];
    _greenOffset = stack[base + 5];
    _blueOffset = stack[base + 6];
    _alphaOffset = stack[base + 7];
    _colorChanged();
  }

  void _setIdentityColor() {
    _redMultiplier = 1.0;
    _greenMultiplier = 1.0;
    _blueMultiplier = 1.0;
    _alphaMultiplier = 1.0;
    _redOffset = 0.0;
    _greenOffset = 0.0;
    _blueOffset = 0.0;
    _alphaOffset = 0.0;
    _colorChanged();
  }

  void _colorChanged() {
    _hasColorTransform =
        _redMultiplier != 1.0 ||
        _greenMultiplier != 1.0 ||
        _blueMultiplier != 1.0 ||
        _alphaMultiplier != 1.0 ||
        _redOffset != 0.0 ||
        _greenOffset != 0.0 ||
        _blueOffset != 0.0 ||
        _alphaOffset != 0.0;
    _colorSnapshot = null;
    _colorVersion++;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _stage = null;
    _renderStats = null;
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;
}

class GCanvasRenderer implements _GDisposable {
  final GRenderContext _context = GRenderContext();
  final Paint _layerPaint = Paint();
  final Paint _maskPaint = Paint();
  final Paint _filterPaint = Paint();
  final Paint _outerPaint = Paint();
  final Paint _innerEffectPaint = Paint();
  final Paint _innerMaskPaint = Paint();
  final GMatrix2 _maskInverse = GMatrix2();
  final GMatrix2 _maskRelative = GMatrix2();
  final GBounds _filterBounds = GBounds.empty();
  final GBounds _innerWorkBounds = GBounds.empty();
  final List<GBounds> _effectBoundsScratch = <GBounds>[];
  final Expando<_CanvasFilterCache> _filterCache = Expando<_CanvasFilterCache>(
    'graphx.canvasFilter',
  );
  final Expando<_CanvasChainCache> _chainCache = Expando<_CanvasChainCache>(
    'graphx.canvasFilterChain',
  );
  bool _allowRasterCache = true;

  void render(Canvas canvas, GStage stage) {
    final stats = stage._activeStats?.render;
    final int startedAt = stats == null ? 0 : getTimerMicros();

    final ctx = _context;
    ctx.begin(canvas, stage);
    stage.beginRenderPass();
    try {
      if (!_paintExplicitViews(canvas, stage, ctx, stats)) {
        _paintNode(stage.root, ctx, 1.0, stats);
      }
    } finally {
      stage.endRenderPass();
      ctx.end();
      stats?.paint.record(getTimerMicros() - startedAt);
    }
  }

  void _paintNode(
    GNode node,
    GRenderContext context,
    double parentAlpha,
    GRenderStats? stats,
  ) {
    stats?.nodesVisited.increment();
    if (!node.active || !node._visible) return;
    if (node is GRenderGroup && !_renderGroupVisible(node, context)) return;
    if (_isActiveMaskSource(node)) return;
    if (_allowRasterCache &&
        _tryPaintCache(node, context, parentAlpha, stats)) {
      return;
    }

    final composite = node._composite;
    assert(
      !(composite?.directConflict ?? false),
      'GCompositeMode.direct cannot satisfy this node compositing state.',
    );

    final nodeAlpha = node._alpha;
    final alpha = parentAlpha * nodeAlpha;
    if (alpha <= 0.0) return;

    final color = composite?.colorTransform;
    if (color != null) context._pushColorTransform(color);

    final layer = composite?.requiresLayer ?? false;
    final canvas = context.canvas;
    final transformed = node.hasLocalTransform;
    final clip = composite?.clip;
    final needsSave = transformed || clip != null;

    if (needsSave) {
      stats?.canvasSaves.increment();
      canvas.save();
    }

    final prevAlpha = context.alpha;
    try {
      if (transformed) {
        stats?.transformsApplied.increment();
        context.transform(node.localMatrix);
      }
      if (clip != null) {
        stats?.clipsApplied.increment();
        clip._apply(canvas, node);
      }

      if (layer) {
        _paintLayer(node, context, parentAlpha, nodeAlpha, composite!, stats);
      } else {
        context.alpha = alpha;
        _paintContents(node, context, alpha, stats);
      }
    } finally {
      context.alpha = prevAlpha;
      if (needsSave) canvas.restore();
      if (color != null) context._popColorTransform();
    }
  }

  void _paintLayer(
    GNode node,
    GRenderContext context,
    double parentAlpha,
    double nodeAlpha,
    _GNodeComposite composite,
    GRenderStats? stats, {
    ui.BlendMode? blendModeOverride,
  }) {
    final canvas = context.canvas;
    final sourceRect = _sourceEffectRect(node);
    final filters = composite.filters;
    final hasFilters = filters != null;
    final layerBounds = hasFilters
        ? _filterBoundsRect(sourceRect, filters, 0, filters.length)
        : sourceRect;

    // Same transparent-black issue as inherited AO, but only for an explicit
    // color-matrix filter that can create alpha from transparent input.
    final clipFilterOutput =
        kIsWeb &&
        composite.filterAffectsTransparentBlack &&
        layerBounds != null;
    if (clipFilterOutput) {
      stats?.canvasSaves.increment();
      canvas.save();
      canvas.clipRect(layerBounds);
    }

    _layerPaint
      ..color = ui.Color.fromRGBO(255, 255, 255, nodeAlpha)
      ..blendMode = blendModeOverride ?? composite.blendMode
      ..colorFilter = null
      ..imageFilter = hasFilters && !composite.hasBranchingFilter
          ? _resolveFilterRange(composite, filters, 0, filters.length)
          : null;
    context._saveLayer(layerBounds, _layerPaint);

    context.alpha = parentAlpha;
    if (hasFilters && composite.hasBranchingFilter) {
      _paintFilterPrefix(
        node,
        context,
        parentAlpha,
        composite,
        filters,
        filters.length,
        sourceRect,
        stats,
      );
    } else {
      _paintLayerSource(
        node,
        context,
        parentAlpha,
        composite,
        sourceRect,
        stats,
      );
    }

    canvas.restore();
    if (clipFilterOutput) canvas.restore();
  }

  void _paintLayerSource(
    GNode node,
    GRenderContext context,
    double parentAlpha,
    _GNodeComposite composite,
    ui.Rect? sourceRect,
    GRenderStats? stats,
  ) {
    _paintContents(node, context, parentAlpha, stats);

    final mask = composite.mask;
    if (mask == null) return;
    _maskPaint
      ..blendMode = composite.maskMode == GMaskMode.alphaInverse
          ? ui.BlendMode.dstOut
          : ui.BlendMode.dstIn
      ..colorFilter = null
      ..imageFilter = null;
    stats?.masksApplied.increment();
    context._saveLayer(sourceRect, _maskPaint);
    _paintMask(mask, node, context, stats);
    context.canvas.restore();
  }

  void _paintFilterPrefix(
    GNode node,
    GRenderContext context,
    double parentAlpha,
    _GNodeComposite composite,
    List<GFilter> filters,
    int count,
    ui.Rect? sourceRect,
    GRenderStats? stats,
  ) {
    if (count == 0) {
      _paintLayerSource(
        node,
        context,
        parentAlpha,
        composite,
        sourceRect,
        stats,
      );
      return;
    }

    var branchIndex = -1;
    for (var i = count - 1; i >= 0; --i) {
      if (_isBranchingFilter(filters[i])) {
        branchIndex = i;
        break;
      }
    }

    // Fuse every contiguous non-branching suffix into one native ImageFilter
    // chain. This keeps blur/matrix segments at one layer around branch effects.
    if (branchIndex < count - 1) {
      final start = branchIndex + 1;
      final bounds = _filterBoundsRect(sourceRect, filters, 0, count);
      final clipped =
          kIsWeb &&
          _rangeAffectsTransparentBlack(filters, start, count) &&
          bounds != null;
      if (clipped) {
        stats?.canvasSaves.increment();
        context.canvas.save();
        context.canvas.clipRect(bounds);
      }
      _filterPaint
        ..color = const ui.Color(0xffffffff)
        ..blendMode = ui.BlendMode.srcOver
        ..colorFilter = null
        ..imageFilter = _resolveFilterRange(composite, filters, start, count);
      context._saveLayer(bounds, _filterPaint);
      _paintFilterPrefix(
        node,
        context,
        parentAlpha,
        composite,
        filters,
        start,
        sourceRect,
        stats,
      );
      context.canvas.restore();
      if (clipped) context.canvas.restore();
      return;
    }

    final filter = filters[count - 1];
    if (!_isBranchingFilter(filter)) {
      // No branching effect exists in this prefix, so the whole prefix is one
      // linear native chain rather than one saveLayer per filter.
      final bounds = _filterBoundsRect(sourceRect, filters, 0, count);
      final clipped =
          kIsWeb &&
          _rangeAffectsTransparentBlack(filters, 0, count) &&
          bounds != null;
      if (clipped) {
        stats?.canvasSaves.increment();
        context.canvas.save();
        context.canvas.clipRect(bounds);
      }
      _filterPaint
        ..color = const ui.Color(0xffffffff)
        ..blendMode = ui.BlendMode.srcOver
        ..colorFilter = null
        ..imageFilter = _resolveFilterRange(composite, filters, 0, count);
      context._saveLayer(bounds, _filterPaint);
      _paintLayerSource(
        node,
        context,
        parentAlpha,
        composite,
        sourceRect,
        stats,
      );
      context.canvas.restore();
      if (clipped) context.canvas.restore();
      return;
    }

    if (filter is GBevelFilter) {
      _paintBevelFilter(
        node,
        context,
        parentAlpha,
        composite,
        filters,
        count - 1,
        filter,
        sourceRect,
        stats,
      );
      return;
    }

    if (_isInnerFilter(filter)) {
      _paintInnerFilter(
        node,
        context,
        parentAlpha,
        composite,
        filters,
        count - 1,
        filter,
        sourceRect,
        stats,
      );
      return;
    }

    final bounds = _filterBoundsRect(sourceRect, filters, 0, count);
    final cache = _resolveOuterFilter(filter);
    _outerPaint
      ..color = const ui.Color(0xffffffff)
      ..blendMode = ui.BlendMode.srcOver
      ..imageFilter = cache.imageFilter
      ..colorFilter = cache.colorFilter;
    context._saveLayer(bounds, _outerPaint);
    _paintFilterPrefix(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      count - 1,
      sourceRect,
      stats,
    );
    context.canvas.restore();

    // The uncached path replays only this branching prefix. If the node's
    // retained raster cache is enabled, the completed filtered subtree replaces
    // this live path after capture.
    _paintFilterPrefix(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      count - 1,
      sourceRect,
      stats,
    );
  }

  void _paintInnerFilter(
    GNode node,
    GRenderContext context,
    double parentAlpha,
    _GNodeComposite composite,
    List<GFilter> filters,
    int prefixCount,
    GFilter filter,
    ui.Rect? sourceRect,
    GRenderStats? stats,
  ) {
    _paintFilterPrefix(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      prefixCount,
      sourceRect,
      stats,
    );

    final bounds = _filterBoundsRect(sourceRect, filters, 0, prefixCount);
    if (bounds == null) return;
    final cache = _resolveInnerFilter(filter);
    _paintInnerEffectBranch(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      prefixCount,
      sourceRect,
      stats,
      workBounds: _innerWorkBoundsRect(bounds, filter),
      imageFilter: cache.imageFilter!,
      colorFilter: cache.colorFilter!,
    );
  }

  void _paintBevelFilter(
    GNode node,
    GRenderContext context,
    double parentAlpha,
    _GNodeComposite composite,
    List<GFilter> filters,
    int prefixCount,
    GBevelFilter filter,
    ui.Rect? sourceRect,
    GRenderStats? stats,
  ) {
    // Preserve once, then generate opposite inner highlight/shadow edges.
    _paintFilterPrefix(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      prefixCount,
      sourceRect,
      stats,
    );

    final bounds = _filterBoundsRect(sourceRect, filters, 0, prefixCount);
    if (bounds == null) return;
    final cache = _resolveBevelFilter(filter);
    final workBounds = _bevelWorkBoundsRect(bounds, filter);

    // Shadow first, highlight second at soft corner overlaps.
    _paintInnerEffectBranch(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      prefixCount,
      sourceRect,
      stats,
      workBounds: workBounds,
      imageFilter: cache.imageFilter2!,
      colorFilter: cache.colorFilter2!,
    );
    _paintInnerEffectBranch(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      prefixCount,
      sourceRect,
      stats,
      workBounds: workBounds,
      imageFilter: cache.imageFilter!,
      colorFilter: cache.colorFilter!,
    );
  }

  void _paintInnerEffectBranch(
    GNode node,
    GRenderContext context,
    double parentAlpha,
    _GNodeComposite composite,
    List<GFilter> filters,
    int prefixCount,
    ui.Rect? sourceRect,
    GRenderStats? stats, {
    required ui.Rect workBounds,
    required ui.ImageFilter imageFilter,
    required ui.ColorFilter colorFilter,
  }) {
    _innerEffectPaint
      ..color = const ui.Color(0xffffffff)
      ..blendMode = ui.BlendMode.srcOver
      ..imageFilter = null
      ..colorFilter = colorFilter;
    context._saveLayer(workBounds, _innerEffectPaint);
    _paintFilterPrefix(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      prefixCount,
      sourceRect,
      stats,
    );

    _innerMaskPaint
      ..color = const ui.Color(0xffffffff)
      ..blendMode = ui.BlendMode.dstOut
      ..colorFilter = null
      ..imageFilter = imageFilter;
    context._saveLayer(workBounds, _innerMaskPaint);
    _paintFilterPrefix(
      node,
      context,
      parentAlpha,
      composite,
      filters,
      prefixCount,
      sourceRect,
      stats,
    );
    context.canvas.restore();
    context.canvas.restore();
  }

  ui.Rect? _sourceEffectRect(GNode node) {
    final bounds = _effectBoundsAt(0);
    _computeEffectBounds(node, bounds, 0, includeOwnFilters: false);
    return _boundsRect(bounds);
  }

  void _computeEffectBounds(
    GNode node,
    GBounds out,
    int depth, {
    required bool includeOwnFilters,
  }) {
    out.copyFrom(node._ensureSelfBounds());
    final children = node._children;
    if (children != null) {
      for (var i = 0; i < children.length; ++i) {
        final child = children[i];
        if (!child.active || !child._visible) continue;
        final childBounds = _effectBoundsAt(depth + 1);
        _computeEffectBounds(
          child,
          childBounds,
          depth + 1,
          includeOwnFilters: true,
        );
        if (childBounds.isEmpty) continue;
        if (child.hasLocalTransform) {
          _includeTransformedBounds(out, childBounds, child.localMatrix);
        } else {
          out.includeBounds(childBounds);
        }
      }
    }

    if (!includeOwnFilters) return;
    final filters = node._composite?.filters;
    if (filters == null) return;
    for (var i = 0; i < filters.length; ++i) {
      filters[i]._expandBounds(out);
    }
  }

  GBounds _effectBoundsAt(int depth) {
    while (_effectBoundsScratch.length <= depth) {
      _effectBoundsScratch.add(GBounds.empty());
    }
    return _effectBoundsScratch[depth];
  }

  void _includeTransformedBounds(GBounds out, GBounds input, GMatrix2 m) {
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

  ui.Rect? _boundsRect(GBounds bounds) => bounds.isEmpty
      ? null
      : ui.Rect.fromLTRB(bounds.x1, bounds.y1, bounds.x2, bounds.y2);

  ui.Rect? _filterBoundsRect(
    ui.Rect? source,
    List<GFilter> filters,
    int start,
    int end,
  ) {
    if (source == null) return null;
    final bounds = _filterBounds
      ..set(source.left, source.top, source.right, source.bottom);
    for (var i = start; i < end; ++i) {
      filters[i]._expandBounds(bounds);
    }
    return ui.Rect.fromLTRB(bounds.x1, bounds.y1, bounds.x2, bounds.y2);
  }

  bool _rangeAffectsTransparentBlack(
    List<GFilter> filters,
    int start,
    int end,
  ) {
    for (var i = start; i < end; ++i) {
      final filter = filters[i];
      if (filter is GColorMatrixFilter && filter.matrix[19] > 0.0) return true;
    }
    return false;
  }

  ui.ImageFilter _resolveFilterRange(
    _GNodeComposite composite,
    List<GFilter> filters,
    int start,
    int end,
  ) {
    final cache = _chainCache[composite] ??= _CanvasChainCache();
    if (cache.version != composite.filterVersion) {
      cache
        ..version = composite.filterVersion
        ..imageFilter = null;
      cache.ranges?.clear();
    }

    final full = start == 0 && end == filters.length;
    if (full && cache.imageFilter != null) return cache.imageFilter!;

    final key = (start << 16) | end;
    if (!full) {
      final hit = cache.ranges?[key];
      if (hit != null) return hit;
    }

    ui.ImageFilter? result;
    for (var i = start; i < end; ++i) {
      final next = _resolveNativeFilter(filters[i]);
      result = result == null
          ? next
          : ui.ImageFilter.compose(outer: next, inner: result);
    }
    final resolved = result!;
    if (full) {
      cache.imageFilter = resolved;
    } else {
      (cache.ranges ??= <int, ui.ImageFilter>{})[key] = resolved;
    }
    return resolved;
  }

  ui.ImageFilter _resolveNativeFilter(GFilter filter) {
    final cache = _filterCache[filter] ??= _CanvasFilterCache();
    if (cache.version == filter._version && cache.imageFilter != null) {
      return cache.imageFilter!;
    }

    final ui.ImageFilter result;
    if (filter is GBlurFilter) {
      result = ui.ImageFilter.blur(
        sigmaX: filter.blurX,
        sigmaY: filter.blurY,
        tileMode: ui.TileMode.decal,
      );
    } else if (filter is GColorMatrixFilter) {
      result = ui.ColorFilter.matrix(filter.matrix);
    } else if (filter is GShaderFilter) {
      if (!ui.ImageFilter.isShaderFilterSupported) {
        throw UnsupportedError(
          'GShaderFilter requires a backend supporting ImageFilter.shader.',
        );
      }
      result = ui.ImageFilter.shader(filter.shader);
    } else {
      throw StateError('Filter requires a branching Canvas effect.');
    }

    cache
      ..version = filter._version
      ..imageFilter = result
      ..colorFilter = null;
    return result;
  }

  bool _isBranchingFilter(GFilter filter) =>
      filter is GDropShadowFilter ||
      filter is GGlowFilter ||
      filter is GOutlineFilter ||
      filter is GBevelFilter;

  bool _isInnerFilter(GFilter filter) =>
      (filter is GDropShadowFilter && filter.inner) ||
      (filter is GGlowFilter && filter.inner);

  _CanvasFilterCache _resolveBevelFilter(GBevelFilter filter) {
    final cache = _filterCache[filter] ??= _CanvasFilterCache();
    if (cache.version == filter._version &&
        cache.imageFilter != null &&
        cache.colorFilter != null &&
        cache.imageFilter2 != null &&
        cache.colorFilter2 != null) {
      return cache;
    }

    cache
      ..version = filter._version
      ..imageFilter = _composeEffectImageFilter(
        offsetX: filter.offsetX,
        offsetY: filter.offsetY,
        blurX: filter.blurX,
        blurY: filter.blurY,
      )
      ..colorFilter = ui.ColorFilter.mode(
        filter.highlightColor,
        ui.BlendMode.srcIn,
      )
      ..imageFilter2 = _composeEffectImageFilter(
        offsetX: -filter.offsetX,
        offsetY: -filter.offsetY,
        blurX: filter.blurX,
        blurY: filter.blurY,
      )
      ..colorFilter2 = ui.ColorFilter.mode(
        filter.shadowColor,
        ui.BlendMode.srcIn,
      );
    return cache;
  }

  ui.Rect _bevelWorkBoundsRect(ui.Rect source, GBevelFilter filter) {
    final px = filter.offsetX.abs() + _blurPadding(filter.blurX);
    final py = filter.offsetY.abs() + _blurPadding(filter.blurY);
    return ui.Rect.fromLTRB(
      source.left - px,
      source.top - py,
      source.right + px,
      source.bottom + py,
    );
  }

  _CanvasFilterCache _resolveInnerFilter(GFilter filter) {
    final cache = _filterCache[filter] ??= _CanvasFilterCache();
    if (cache.version == filter._version &&
        cache.imageFilter != null &&
        cache.colorFilter != null) {
      return cache;
    }

    double offsetX = 0.0;
    double offsetY = 0.0;
    double blurX;
    double blurY;
    double spread = 0.0;
    ui.Color color;
    if (filter is GDropShadowFilter && filter.inner) {
      offsetX = filter.offsetX;
      offsetY = filter.offsetY;
      blurX = filter.blurX;
      blurY = filter.blurY;
      color = filter.color;
    } else if (filter is GGlowFilter && filter.inner) {
      blurX = filter.blurX;
      blurY = filter.blurY;
      spread = filter.spread;
      color = filter.color;
    } else {
      throw StateError('Filter is not an inner Canvas effect.');
    }

    cache
      ..version = filter._version
      ..imageFilter = _composeEffectImageFilter(
        offsetX: offsetX,
        offsetY: offsetY,
        blurX: blurX,
        blurY: blurY,
        spreadX: spread,
        spreadY: spread,
        erode: true,
      )
      ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn);
    return cache;
  }

  ui.Rect _innerWorkBoundsRect(ui.Rect source, GFilter filter) {
    final bounds = _innerWorkBounds
      ..set(source.left, source.top, source.right, source.bottom);
    if (filter is GDropShadowFilter && filter.inner) {
      _expandOuterBounds(
        bounds,
        offsetX: filter.offsetX,
        offsetY: filter.offsetY,
        blurX: filter.blurX,
        blurY: filter.blurY,
      );
    } else if (filter is GGlowFilter && filter.inner) {
      // Erosion contracts the mask, so only Gaussian sampling needs extra work
      // pixels. The semantic filter bounds remain unchanged.
      _expandOuterBounds(bounds, blurX: filter.blurX, blurY: filter.blurY);
    } else {
      throw StateError('Filter is not an inner Canvas effect.');
    }
    return ui.Rect.fromLTRB(bounds.x1, bounds.y1, bounds.x2, bounds.y2);
  }

  ui.ImageFilter _composeEffectImageFilter({
    double offsetX = 0.0,
    double offsetY = 0.0,
    double blurX = 0.0,
    double blurY = 0.0,
    double spreadX = 0.0,
    double spreadY = 0.0,
    bool erode = false,
  }) {
    ui.ImageFilter? result;
    if (spreadX > 0.0 || spreadY > 0.0) {
      result = erode
          ? ui.ImageFilter.erode(radiusX: spreadX, radiusY: spreadY)
          : ui.ImageFilter.dilate(radiusX: spreadX, radiusY: spreadY);
    }
    if (blurX > 0.0 || blurY > 0.0) {
      final blur = ui.ImageFilter.blur(
        sigmaX: blurX,
        sigmaY: blurY,
        tileMode: ui.TileMode.decal,
      );
      result = result == null
          ? blur
          : ui.ImageFilter.compose(outer: blur, inner: result);
    }
    if (offsetX != 0.0 || offsetY != 0.0) {
      final offset = ui.ImageFilter.matrix(
        Float64List.fromList(<double>[
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
          1,
          0,
          offsetX,
          offsetY,
          0,
          1,
        ]),
        filterQuality: ui.FilterQuality.medium,
      );
      result = result == null
          ? offset
          : ui.ImageFilter.compose(outer: offset, inner: result);
    }
    return result ?? ui.ImageFilter.blur();
  }

  _CanvasFilterCache _resolveOuterFilter(GFilter filter) {
    final cache = _filterCache[filter] ??= _CanvasFilterCache();
    if (cache.version == filter._version &&
        cache.imageFilter != null &&
        cache.colorFilter != null) {
      return cache;
    }

    double offsetX;
    double offsetY;
    double blurX;
    double blurY;
    double spreadX;
    double spreadY;
    ui.Color color;
    if (filter is GDropShadowFilter && !filter.inner) {
      offsetX = filter.offsetX;
      offsetY = filter.offsetY;
      blurX = filter.blurX;
      blurY = filter.blurY;
      spreadX = 0.0;
      spreadY = 0.0;
      color = filter.color;
    } else if (filter is GGlowFilter && !filter.inner) {
      offsetX = 0.0;
      offsetY = 0.0;
      blurX = filter.blurX;
      blurY = filter.blurY;
      spreadX = filter.spread;
      spreadY = filter.spread;
      color = filter.color;
    } else if (filter is GOutlineFilter) {
      offsetX = 0.0;
      offsetY = 0.0;
      blurX = filter.softness;
      blurY = filter.softness;
      spreadX = filter.width;
      spreadY = filter.width;
      color = filter.color;
    } else {
      throw StateError('Filter is not an outer Canvas effect.');
    }

    cache
      ..version = filter._version
      ..imageFilter = _composeEffectImageFilter(
        offsetX: offsetX,
        offsetY: offsetY,
        blurX: blurX,
        blurY: blurY,
        spreadX: spreadX,
        spreadY: spreadY,
      )
      ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn);
    return cache;
  }

  void _paintMask(
    GNode mask,
    GNode target,
    GRenderContext context,
    GRenderStats? stats,
  ) {
    if (!mask.active || !mask._visible) return;
    if (!_sharesRenderSpace(mask, target)) {
      assert(
        false,
        'Mask and target must belong to the same Stage or detached tree.',
      );
      return;
    }

    target._ensureWorldTransform();
    mask._ensureWorldTransform();
    if (!target._worldMatrix!.invertInto(_maskInverse)) return;
    _maskRelative.setProduct(_maskInverse, mask._worldMatrix!);

    final canvas = context.canvas;
    stats?.canvasSaves.increment();
    canvas.save();
    final prevAlpha = context.alpha;
    context._pushIdentityColor();
    final maskColor = mask._composite?.colorTransform;
    if (maskColor != null) context._pushColorTransform(maskColor);
    try {
      context.transform(_maskRelative);
      final maskComposite = mask._composite;
      final maskClip = maskComposite?.clip;
      if (maskClip != null) {
        stats?.clipsApplied.increment();
        maskClip._apply(canvas, mask);
      }
      context.alpha = mask._alpha;
      _paintContents(mask, context, mask._alpha, stats);
    } finally {
      if (maskColor != null) context._popColorTransform();
      context._popColorTransform();
      context.alpha = prevAlpha;
      canvas.restore();
    }
  }

  bool _sharesRenderSpace(GNode a, GNode b) {
    final aStage = a._stage;
    final bStage = b._stage;
    if (aStage != null || bStage != null) {
      return aStage != null && identical(aStage, bStage);
    }

    GNode aRoot = a;
    while (aRoot._parent != null) {
      aRoot = aRoot._parent!;
    }
    GNode bRoot = b;
    while (bRoot._parent != null) {
      bRoot = bRoot._parent!;
    }
    return identical(aRoot, bRoot);
  }

  void _paintContents(
    GNode node,
    GRenderContext context,
    double childParentAlpha,
    GRenderStats? stats,
  ) {
    if (node._paintSelf) {
      stats?.nodesPainted.increment();
      node.paintSelf(context);
    }
    final children = node._children;
    if (children == null) return;
    if (node is GViewportGroup) {
      _paintViewportGroupChildren(node, context, childParentAlpha, stats);
      return;
    }
    for (var i = 0; i < children.length; ++i) {
      _paintNode(children[i], context, childParentAlpha, stats);
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _context.dispose();
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;
}

final class _CanvasFilterCache {
  int version = -1;
  ui.ImageFilter? imageFilter;
  ui.ColorFilter? colorFilter;
  ui.ImageFilter? imageFilter2;
  ui.ColorFilter? colorFilter2;
}

final class _CanvasChainCache {
  int version = -1;
  ui.ImageFilter? imageFilter;
  Map<int, ui.ImageFilter>? ranges;
}
