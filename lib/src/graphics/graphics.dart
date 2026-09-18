part of 'package:graphx/graphx.dart';

/// Retained vector drawing commands with the familiar GraphX/Flash grammar.
///
/// Style changes create retained batch boundaries. Unchanged graphics repaint
/// without rebuilding paths, bounds, or gradient shaders.
final class GGraphics {
  GGraphics._(this._onGeometryChanged, this._onPaintChanged);

  final void Function() _onGeometryChanged;
  final void Function() _onPaintChanged;
  final List<_GGraphicsBatch> _batches = <_GGraphicsBatch>[];
  final Set<ui.Shader> _ownedShaders = <ui.Shader>{};
  final Set<GShaderInstance> _shaderInstances = <GShaderInstance>{};
  final GBounds _bounds = GBounds.empty();
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  _GGraphicsBrush? _fill;
  _GGraphicsStroke? _stroke;
  _GGraphicsBatch? _openBatch;
  bool _fillUsed = false;
  bool _boundsDirty = true;
  int _batchDepth = 0;
  bool _batchedGeometryChange = false;
  double _alphaFilterAlpha = 1.0;
  ColorFilter? _alphaFilter;

  bool get isEmpty {
    for (var i = 0; i < _batches.length; ++i) {
      if (_batches[i].paints) return false;
    }
    return true;
  }

  /// Retained style/geometry groups. Intended for diagnostics and benchmarks.
  int get batchCount => _batches.length;

  GGraphics beginFill(
    Color color, [
    bool antiAlias = true,
    BlendMode blendMode = BlendMode.srcOver,
  ]) {
    _setFill(
      _GSolidGraphicsBrush(color, isAntiAlias: antiAlias, blendMode: blendMode),
    );
    return this;
  }

  GGraphics beginGradientFill(
    GGradientType type,
    List<Color> colors, {
    List<double>? ratios,
    Alignment? begin,
    Alignment? end,
    double rotation = 0.0,
    TileMode tileMode = TileMode.clamp,
    Rect? gradientBox,
    double radius = 0.5,
    double focalRadius = 0.0,
    double sweepStartAngle = 0.0,
    double sweepEndAngle = math.pi * 2.0,
    bool antiAlias = true,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    _setFill(
      _GGradientGraphicsBrush(
        type,
        colors,
        ratios: ratios,
        begin: begin ?? Alignment.center,
        end: end ?? Alignment.centerRight,
        rotation: rotation,
        tileMode: tileMode,
        gradientBox: gradientBox,
        radius: radius,
        focalRadius: focalRadius,
        sweepStartAngle: sweepStartAngle,
        sweepEndAngle: sweepEndAngle,
        isAntiAlias: antiAlias,
        blendMode: blendMode,
      ),
    );
    return this;
  }

  /// GraphX-style bitmap fill backed directly by a [GTexture].
  ///
  /// The texture transform is snapshotted when the style is set. Atlas-region
  /// textures are intentionally rejected for now because native ImageShader
  /// repeat/clamp operates on the complete backing image, which would make
  /// region sampling untruthful at the edges.
  GGraphics beginBitmapFill(
    GTexture texture, [
    GMatrix2? matrix,
    bool repeat = true,
    bool smooth = false,
    BlendMode blendMode = BlendMode.srcOver,
  ]) {
    if (texture.isDisposed) {
      throw StateError('Cannot use a disposed GTexture as a bitmap fill.');
    }
    final frame = texture.frame;
    final image = texture.image;
    final fullFrame =
        !frame.rotated &&
        frame.offsetX == 0.0 &&
        frame.offsetY == 0.0 &&
        frame.region.x == 0.0 &&
        frame.region.y == 0.0 &&
        frame.region.w == image.width.toDouble() &&
        frame.region.h == image.height.toDouble();
    if (!fullFrame) {
      throw UnsupportedError(
        'beginBitmapFill currently requires a full-frame GTexture. '
        'Atlas-region shader sampling needs a region-aware backend.',
      );
    }

    final invScale = 1.0 / texture.scale;
    final storage = Float64List(16);
    storage[10] = 1.0;
    storage[15] = 1.0;
    if (matrix == null) {
      storage[0] = invScale;
      storage[5] = invScale;
    } else {
      storage[0] = matrix.a * invScale;
      storage[1] = matrix.b * invScale;
      storage[4] = matrix.c * invScale;
      storage[5] = matrix.d * invScale;
      storage[12] = matrix.tx;
      storage[13] = matrix.ty;
    }

    final tileMode = repeat ? TileMode.repeated : TileMode.clamp;
    final shader = ui.ImageShader(image, tileMode, tileMode, storage);
    _ownedShaders.add(shader);
    _setFill(
      _GBitmapGraphicsBrush(
        texture,
        shader,
        repeat: repeat,
        smooth: smooth,
        blendMode: blendMode,
      ),
    );
    return this;
  }

  /// Uses a caller-owned programmable shader instance as the current fill.
  ///
  /// Uniform/sampler mutations repaint automatically without rebuilding paths.
  GGraphics beginShaderFill(
    GShaderInstance shader, [
    bool antiAlias = true,
    BlendMode blendMode = BlendMode.srcOver,
    FilterQuality filterQuality = FilterQuality.low,
  ]) {
    if (shader.isDisposed) {
      throw StateError('Cannot use a disposed GShaderInstance.');
    }
    _watchShader(shader);
    _setFill(
      _GProgramShaderGraphicsBrush(
        shader,
        isAntiAlias: antiAlias,
        blendMode: blendMode,
        filterQuality: filterQuality,
      ),
    );
    return this;
  }

  /// Low-level fill for an already-created Canvas [ui.Shader].
  GGraphics beginPaintShaderFill(
    GPaintShader shader, [
    bool antiAlias = true,
    BlendMode blendMode = BlendMode.srcOver,
    FilterQuality filterQuality = FilterQuality.low,
  ]) {
    _setFill(
      _GPaintShaderGraphicsBrush(
        shader,
        isAntiAlias: antiAlias,
        blendMode: blendMode,
        filterQuality: filterQuality,
      ),
    );
    return this;
  }

  /// GraphX1-compatible low-level Canvas-shader alias.
  GGraphics beginShader(
    GPaintShader shader, [
    bool antiAlias = true,
    BlendMode blendMode = BlendMode.srcOver,
    FilterQuality filterQuality = FilterQuality.low,
  ]) => beginPaintShaderFill(shader, antiAlias, blendMode, filterQuality);

  GGraphics endFill() {
    _setFill(null);
    return this;
  }

  /// Familiar GraphX lineStyle ordering. `pixelHinting` is accepted for source
  /// compatibility but has no Canvas equivalent and is intentionally ignored.
  GGraphics lineStyle([
    double thickness = 0.0,
    Color color = const Color(0xff000000),
    bool pixelHinting = true,
    StrokeCap? caps,
    StrokeJoin? joints,
    double miterLimit = 3.0,
    BlendMode blendMode = BlendMode.srcOver,
  ]) {
    assert(thickness.isFinite && thickness >= 0.0);
    assert(miterLimit.isFinite && miterLimit >= 0.0);
    _closeBatch();
    _stroke = _GGraphicsStroke(
      brush: _GSolidGraphicsBrush(color, blendMode: blendMode),
      width: thickness,
      cap: caps ?? StrokeCap.round,
      join: joints ?? StrokeJoin.miter,
      miterLimit: miterLimit,
    );
    return this;
  }

  GGraphics lineGradientStyle(
    GGradientType type,
    List<Color> colors, {
    List<double>? ratios,
    Alignment? begin,
    Alignment? end,
    double rotation = 0.0,
    TileMode tileMode = TileMode.clamp,
    Rect? gradientBox,
    double radius = 0.5,
    double focalRadius = 0.0,
    double sweepStartAngle = 0.0,
    double sweepEndAngle = math.pi * 2.0,
    bool antiAlias = true,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    final stroke = _stroke;
    if (stroke == null) {
      throw StateError('lineGradientStyle() requires lineStyle() first.');
    }
    _closeBatch();
    _stroke = stroke.copyWith(
      brush: _GGradientGraphicsBrush(
        type,
        colors,
        ratios: ratios,
        begin: begin ?? Alignment.center,
        end: end ?? Alignment.centerRight,
        rotation: rotation,
        tileMode: tileMode,
        gradientBox: gradientBox,
        radius: radius,
        focalRadius: focalRadius,
        sweepStartAngle: sweepStartAngle,
        sweepEndAngle: sweepEndAngle,
        isAntiAlias: antiAlias,
        blendMode: blendMode,
      ),
    );
    return this;
  }

  GGraphics endStroke() {
    _closeBatch();
    _stroke = null;
    return this;
  }

  /// Explicit retained batch boundary. Never required for rendering.
  GGraphics end() {
    _closeBatch();
    return this;
  }

  GGraphics moveTo(double x, double y) {
    _ensureBatch().path.moveTo(x, y);
    return _geometryChanged();
  }

  GGraphics lineTo(double x, double y) {
    _ensureBatch().path.lineTo(x, y);
    return _geometryChanged();
  }

  GGraphics curveTo(
    double controlX,
    double controlY,
    double anchorX,
    double anchorY,
  ) {
    _ensureBatch().path.quadraticBezierTo(controlX, controlY, anchorX, anchorY);
    return _geometryChanged();
  }

  GGraphics cubicCurveTo(
    double controlX1,
    double controlY1,
    double controlX2,
    double controlY2,
    double anchorX,
    double anchorY,
  ) {
    _ensureBatch().path.cubicTo(
      controlX1,
      controlY1,
      controlX2,
      controlY2,
      anchorX,
      anchorY,
    );
    return _geometryChanged();
  }

  GGraphics conicCurveTo(
    double controlX,
    double controlY,
    double anchorX,
    double anchorY,
    double weight, [
    bool relative = false,
  ]) {
    final path = _ensureBatch().path;
    if (relative) {
      path.relativeConicTo(controlX, controlY, anchorX, anchorY, weight);
    } else {
      path.conicTo(controlX, controlY, anchorX, anchorY, weight);
    }
    return _geometryChanged();
  }

  GGraphics closePath() {
    _ensureBatch().path.close();
    return _geometryChanged();
  }

  GGraphics drawLine(double x0, double y0, double x1, double y1) {
    _ensureBatch().path
      ..moveTo(x0, y0)
      ..lineTo(x1, y1);
    return _geometryChanged();
  }

  GGraphics drawRect(double x, double y, double width, double height) {
    _ensureBatch().path.addRect(Rect.fromLTWH(x, y, width, height));
    return _geometryChanged();
  }

  GGraphics drawRoundRect(
    double x,
    double y,
    double width,
    double height,
    double radiusX, [
    double? radiusY,
  ]) {
    _ensureBatch().path.addRRect(
      RRect.fromLTRBXY(
        x,
        y,
        x + width,
        y + height,
        radiusX,
        radiusY ?? radiusX,
      ),
    );
    return _geometryChanged();
  }

  GGraphics drawRoundRectComplex(
    double x,
    double y,
    double width,
    double height, [
    double topLeft = 0.0,
    double topRight = 0.0,
    double bottomLeft = 0.0,
    double bottomRight = 0.0,
  ]) {
    _ensureBatch().path.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, width, height),
        topLeft: Radius.circular(topLeft),
        topRight: Radius.circular(topRight),
        bottomLeft: Radius.circular(bottomLeft),
        bottomRight: Radius.circular(bottomRight),
      ),
    );
    return _geometryChanged();
  }

  GGraphics drawCircle(double x, double y, double radius) {
    _ensureBatch().path.addOval(
      Rect.fromCircle(center: Offset(x, y), radius: radius),
    );
    return _geometryChanged();
  }

  GGraphics drawEllipse(double x, double y, double radiusX, double radiusY) {
    _ensureBatch().path.addOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: radiusX * 2.0,
        height: radiusY * 2.0,
      ),
    );
    return _geometryChanged();
  }

  GGraphics drawPath(Path source, [double x = 0.0, double y = 0.0]) {
    _ensureBatch().path.addPath(source, Offset(x, y));
    return _geometryChanged();
  }

  GGraphics drawPolygon(List<Offset> points, [bool close = true]) {
    if (points.isEmpty) return this;
    _ensureBatch().path.addPolygon(points, close);
    return _geometryChanged();
  }

  GGraphics arc(
    double x,
    double y,
    double radius,
    double startAngle,
    double sweepAngle, [
    bool moveTo = false,
  ]) {
    if (sweepAngle == 0.0) return this;
    final oval = Rect.fromCircle(center: Offset(x, y), radius: radius);
    final path = _ensureBatch().path;
    if (moveTo) {
      path.addArc(oval, startAngle, sweepAngle);
    } else {
      path.arcTo(oval, startAngle, sweepAngle, false);
    }
    return _geometryChanged();
  }

  GGraphics arcOval(
    double x,
    double y,
    double radiusX,
    double radiusY,
    double startAngle,
    double sweepAngle,
  ) {
    _ensureBatch().path.addArc(
      Rect.fromCenter(
        center: Offset(x, y),
        width: radiusX * 2.0,
        height: radiusY * 2.0,
      ),
      startAngle,
      sweepAngle,
    );
    return _geometryChanged();
  }

  GGraphics arcToPoint(
    double endX,
    double endY,
    double radius, [
    double rotation = 0.0,
    bool largeArc = false,
    bool clockwise = true,
    bool relative = false,
  ]) {
    if (radius == 0.0) return this;
    final path = _ensureBatch().path;
    if (relative) {
      path.relativeArcToPoint(
        Offset(endX, endY),
        radius: Radius.circular(radius),
        rotation: rotation,
        largeArc: largeArc,
        clockwise: clockwise,
      );
    } else {
      path.arcToPoint(
        Offset(endX, endY),
        radius: Radius.circular(radius),
        rotation: rotation,
        largeArc: largeArc,
        clockwise: clockwise,
      );
    }
    return _geometryChanged();
  }

  GGraphics clear() {
    if (_batches.isEmpty &&
        _fill == null &&
        _stroke == null &&
        _ownedShaders.isEmpty &&
        _shaderInstances.isEmpty) {
      return this;
    }
    _releaseOwnedResources();
    _batches.clear();
    _openBatch = null;
    _fill = null;
    _stroke = null;
    _fillUsed = false;
    _bounds.setEmpty();
    _boundsDirty = false;
    _notifyGeometryChanged();
    return this;
  }

  /// Coalesces all owner invalidation caused by [draw].
  GGraphics batch(void Function(GGraphics graphics) draw) {
    _batchDepth++;
    try {
      draw(this);
    } finally {
      _batchDepth--;
      if (_batchDepth == 0 && _batchedGeometryChange) {
        _batchedGeometryChange = false;
        _onGeometryChanged();
      }
    }
    return this;
  }

  /// Clears and rebuilds while invalidating the owner once.
  GGraphics redraw(void Function(GGraphics graphics) draw) => batch((graphics) {
    graphics.clear();
    draw(graphics);
  });

  /// Requests a repaint without invalidating geometry or bounds.
  ///
  /// Useful after mutating uniforms on a retained FragmentShader.
  void invalidatePaint() => _onPaintChanged();

  void getBounds(GBounds out) {
    _ensureBounds();
    out.copyFrom(_bounds);
  }

  /// Exact for fills. Stroke picking is conservative until a proper stroker or
  /// tessellated stroke representation is available.
  bool hitTestLocal(double x, double y) {
    final point = Offset(x, y);
    for (var i = _batches.length - 1; i >= 0; --i) {
      final batch = _batches[i];
      if (batch.fill != null && batch.path.contains(point)) return true;
      final stroke = batch.stroke;
      if (stroke == null || !batch.strokePathHasGeometry) continue;
      if (batch.strokePathPaintAsFill) {
        if (batch.strokePath.contains(point)) return true;
      } else if (batch.strokePathBounds
          .inflate(stroke.boundsPad)
          .contains(point)) {
        return true;
      }
    }
    return false;
  }

  /// Paints retained Graphics directly with an explicit alpha.
  ///
  /// This remains available for low-level callers outside a GraphX render
  /// traversal. [GShape] uses the render-context path so inherited color state
  /// can be applied without an offscreen layer.
  void paint(Canvas canvas, double alpha) {
    _paint(canvas, alpha, null);
  }

  void _paintContext(GRenderContext context) {
    _paint(
      context.canvas,
      context.alpha,
      context.hasColorTransform ? context._effectiveColorFilter : null,
    );
  }

  void _paint(Canvas canvas, double alpha, ColorFilter? renderFilter) {
    if (alpha <= 0.0) return;
    for (var i = 0; i < _batches.length; ++i) {
      final batch = _batches[i];
      final fill = batch.fill;
      if (fill != null) {
        _configurePaint(_fillPaint, fill, batch, alpha, renderFilter, true);
        canvas.drawPath(batch.path, _fillPaint);
      }
      final stroke = batch.stroke;
      if (stroke != null) {
        if (stroke.geometry != null && !batch.strokePathHasGeometry) continue;
        _strokePaint
          ..style = batch.strokePathPaintAsFill
              ? PaintingStyle.fill
              : PaintingStyle.stroke
          ..strokeWidth = stroke.width
          ..strokeCap = stroke.cap
          ..strokeJoin = stroke.join
          ..strokeMiterLimit = stroke.miterLimit;
        _configurePaint(
          _strokePaint,
          stroke.brush,
          batch,
          alpha,
          renderFilter,
          false,
        );
        canvas.drawPath(batch.strokePath, _strokePaint);
      }
    }
  }

  void _dispose() {
    _releaseOwnedResources();
    _batches.clear();
    _openBatch = null;
    _fill = null;
    _stroke = null;
    _fillUsed = false;
  }

  void _releaseOwnedResources() {
    for (final shader in _shaderInstances) {
      shader._unlisten(_onPaintChanged);
    }
    _shaderInstances.clear();
    _fillPaint.shader = null;
    _strokePaint.shader = null;
    _alphaFilter = null;
    _alphaFilterAlpha = 1.0;
    for (var i = 0; i < _batches.length; ++i) {
      _batches[i].disposeGeneratedShaders();
    }
    for (final shader in _ownedShaders) {
      shader.dispose();
    }
    _ownedShaders.clear();
  }

  void _watchShader(GShaderInstance shader) {
    if (_shaderInstances.add(shader)) shader._listen(_onPaintChanged);
  }

  void _setFill(_GGraphicsBrush? fill) {
    final previous = _fill;
    if (!_fillUsed && previous is _GBitmapGraphicsBrush) {
      if (_ownedShaders.remove(previous.shader)) previous.shader.dispose();
    }
    _closeBatch();
    _fill = fill;
    _fillUsed = false;
  }

  _GGraphicsBatch _ensureBatch() {
    final open = _openBatch;
    if (open != null) return open;
    final batch = _GGraphicsBatch(fill: _fill, stroke: _stroke);
    _batches.add(batch);
    _openBatch = batch;
    if (_fill != null) _fillUsed = true;
    return batch;
  }

  void _closeBatch() {
    _openBatch = null;
  }

  GGraphics _geometryChanged() {
    final batch = _openBatch;
    if (batch != null) batch.geometryVersion++;
    _boundsDirty = true;
    _notifyGeometryChanged();
    return this;
  }

  void _notifyGeometryChanged() {
    if (_batchDepth != 0) {
      _batchedGeometryChange = true;
      return;
    }
    _onGeometryChanged();
  }

  void _ensureBounds() {
    if (!_boundsDirty) return;
    _bounds.setEmpty();
    for (var i = 0; i < _batches.length; ++i) {
      final batch = _batches[i];
      if (!batch.paints) continue;
      final rect = batch.pathBounds;
      if (batch.fill != null && !rect.isEmpty) {
        _bounds.includePoint(rect.left, rect.top);
        _bounds.includePoint(rect.right, rect.bottom);
      }
      final stroke = batch.stroke;
      if (stroke != null && batch.strokePathHasGeometry) {
        final strokeRect = batch.strokePathBounds;
        final pad = batch.strokePathPaintAsFill ? 0.0 : stroke.boundsPad;
        _bounds.includePoint(strokeRect.left - pad, strokeRect.top - pad);
        _bounds.includePoint(strokeRect.right + pad, strokeRect.bottom + pad);
      }
    }
    _boundsDirty = false;
  }

  void _configurePaint(
    Paint paint,
    _GGraphicsBrush brush,
    _GGraphicsBatch batch,
    double alpha,
    ColorFilter? renderFilter,
    bool fill,
  ) {
    paint
      ..blendMode = brush.blendMode
      ..isAntiAlias = brush.isAntiAlias
      ..colorFilter = renderFilter
      ..filterQuality = FilterQuality.low;

    if (brush case _GSolidGraphicsBrush solid) {
      paint
        ..shader = null
        ..color = renderFilter != null || alpha == 1.0
            ? solid.color
            : solid.color.withValues(alpha: solid.color.a * alpha);
      return;
    }

    if (brush case _GBitmapGraphicsBrush bitmap) {
      paint
        ..shader = bitmap.shader
        ..color = const Color(0xffffffff)
        ..filterQuality = bitmap.filterQuality
        ..colorFilter = renderFilter ?? _alphaColorFilter(alpha);
      return;
    }

    final paintBounds = fill ? batch.pathBounds : batch.strokePathBounds;

    if (brush case _GProgramShaderGraphicsBrush shader) {
      shader.size?.set(paintBounds.width, paintBounds.height);
      paint
        ..shader = shader.shader._nativeShader
        ..color = const Color(0xffffffff)
        ..filterQuality = shader.filterQuality
        ..colorFilter = renderFilter ?? _alphaColorFilter(alpha);
      return;
    }

    if (brush case _GPaintShaderGraphicsBrush shader) {
      paint
        ..shader = shader.shader
        ..color = const Color(0xffffffff)
        ..filterQuality = shader.filterQuality
        ..colorFilter = renderFilter ?? _alphaColorFilter(alpha);
      return;
    }

    final gradient = brush as _GGradientGraphicsBrush;
    final shaderVersion = fill
        ? batch.fillShaderVersion
        : batch.strokeShaderVersion;
    Shader? resolved = fill ? batch.fillShader : batch.strokeShader;
    if (resolved == null || shaderVersion != batch.geometryVersion) {
      resolved = _createGradientShader(gradient, paintBounds);
      if (fill) {
        batch.fillShader = resolved;
        batch.fillShaderVersion = batch.geometryVersion;
      } else {
        batch.strokeShader = resolved;
        batch.strokeShaderVersion = batch.geometryVersion;
      }
    }
    paint
      ..shader = resolved
      ..color = const Color(0xffffffff)
      ..colorFilter = renderFilter ?? _alphaColorFilter(alpha);
  }

  ColorFilter? _alphaColorFilter(double alpha) {
    if (alpha == 1.0) return null;
    if (_alphaFilter != null && _alphaFilterAlpha == alpha) return _alphaFilter;
    _alphaFilterAlpha = alpha;
    return _alphaFilter = ColorFilter.mode(
      Color.fromRGBO(255, 255, 255, alpha),
      BlendMode.multiply,
    );
  }

  Shader _createGradientShader(_GGradientGraphicsBrush style, Rect pathBounds) {
    final bounds = style.gradientBox ?? pathBounds;
    final transform = style.rotation == 0.0
        ? null
        : GradientRotation(style.rotation);

    final Gradient gradient;
    switch (style.type) {
      case GGradientType.linear:
        gradient = LinearGradient(
          begin: style.begin,
          end: style.end,
          colors: style.colors,
          stops: style.ratios,
          tileMode: style.tileMode,
          transform: transform,
        );
      case GGradientType.radial:
        gradient = RadialGradient(
          center: style.begin,
          focal: style.end,
          radius: style.radius,
          focalRadius: style.focalRadius,
          colors: style.colors,
          stops: style.ratios,
          tileMode: style.tileMode,
          transform: transform,
        );
      case GGradientType.sweep:
        gradient = SweepGradient(
          center: style.begin,
          startAngle: style.sweepStartAngle,
          endAngle: style.sweepEndAngle,
          colors: style.colors,
          stops: style.ratios,
          tileMode: style.tileMode,
          transform: transform,
        );
    }
    return gradient.createShader(bounds);
  }
}
