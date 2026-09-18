// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

extension GRenderContextColorApi on GRenderContext {
  /// Starts a retained render-context pass without an attached [GStage].
  ///
  /// Extension runtimes such as direct Flutter RenderObjects can reuse the
  /// exact GraphX alpha/color execution path while remaining stage-free. Pair
  /// this with [GRenderContext.end]. The context itself is reusable across
  /// paints; this method resets inherited alpha/color state for each pass.
  void beginDetached(Canvas canvas) => _begin(canvas, null, null);

  /// Applies the current inherited alpha and color transform to a solid color.
  ///
  /// This is intended for custom retained render nodes in extension packages
  /// that draw primitive solid colors directly with [Canvas]. The unchanged
  /// opaque sRGB path returns [color] itself and allocates nothing.
  ui.Color resolveColor(ui.Color color) {
    if (!hasColorTransform && alpha == 1.0 && color.colorSpace == ui.ColorSpace.sRGB) {
      return color;
    }

    var source = color;
    if (source.colorSpace != ui.ColorSpace.sRGB) {
      source = source.withValues(colorSpace: ui.ColorSpace.sRGB);
    }

    var r = source.r;
    var g = source.g;
    var b = source.b;
    var a = source.a;
    if (hasColorTransform) {
      final transform = colorTransform;
      r = (r * transform.redMultiplier + transform.redOffset / 255.0).clamp(
        0.0,
        1.0,
      );
      g = (g * transform.greenMultiplier + transform.greenOffset / 255.0).clamp(
        0.0,
        1.0,
      );
      b = (b * transform.blueMultiplier + transform.blueOffset / 255.0).clamp(
        0.0,
        1.0,
      );
      a = (a * transform.alphaMultiplier + transform.alphaOffset / 255.0).clamp(
        0.0,
        1.0,
      );
    }
    a = (a * alpha).clamp(0.0, 1.0);

    return ui.Color.fromARGB(
      (a * 255.0).round(),
      (r * 255.0).round(),
      (g * 255.0).round(),
      (b * 255.0).round(),
    );
  }

  /// Pushes explicit local color-transform values onto inherited render state.
  ///
  /// This is the allocation-free extension-package seam for retained compiled
  /// runtimes. Composition is exactly the core GraphX rule used for GNode:
  /// local is evaluated first, then the current parent transform. Offsets stay
  /// in 0..255 channel units and are not clamped here.
  void pushColorTransformValues({
    double redMultiplier = 1.0,
    double greenMultiplier = 1.0,
    double blueMultiplier = 1.0,
    double alphaMultiplier = 1.0,
    double redOffset = 0.0,
    double greenOffset = 0.0,
    double blueOffset = 0.0,
    double alphaOffset = 0.0,
  }) {
    assert(
      redMultiplier.isFinite &&
          greenMultiplier.isFinite &&
          blueMultiplier.isFinite &&
          alphaMultiplier.isFinite &&
          redOffset.isFinite &&
          greenOffset.isFinite &&
          blueOffset.isFinite &&
          alphaOffset.isFinite,
    );
    _saveColorState();
    final prm = _redMultiplier;
    final pgm = _greenMultiplier;
    final pbm = _blueMultiplier;
    final pam = _alphaMultiplier;
    _redMultiplier = prm * redMultiplier;
    _greenMultiplier = pgm * greenMultiplier;
    _blueMultiplier = pbm * blueMultiplier;
    _alphaMultiplier = pam * alphaMultiplier;
    _redOffset = prm * redOffset + _redOffset;
    _greenOffset = pgm * greenOffset + _greenOffset;
    _blueOffset = pbm * blueOffset + _blueOffset;
    _alphaOffset = pam * alphaOffset + _alphaOffset;
    _colorChanged();
  }

  /// Pops one state pushed by [pushColorTransformValues].
  void popColorTransformValues() => _popColorTransform();
}
