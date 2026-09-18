// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Backend/output density for the active render target.
///
/// Hosted rendering inherits the owning Stage viewport density. Offscreen
/// renderers temporarily override that density with their explicit backing
/// scale so renderables never need to inspect Flutter global view state.
final Expando<double> _gRenderPixelScaleOverrides = Expando<double>(
  'graphx.renderPixelScale',
);

extension GRenderContextPixelScale on GRenderContext {
  /// Physical backing pixels per viewport/render-target logical unit.
  ///
  /// This is the raw output density before an explicit render-view transform.
  /// Use [pixelScale] for pixel-sensitive world rendering such as SDF smoothing.
  double get targetPixelScale =>
      _gRenderPixelScaleOverrides[this] ?? _stage?.devicePixelRatio ?? 1.0;

  /// Conservative physical pixels per world logical unit before node transforms.
  ///
  /// This combines output density with the active render-view scale while
  /// keeping camera/view transforms out of retained node world matrices. A
  /// renderer that also depends on node scale should multiply that scale by
  /// this value.
  double get pixelScale => targetPixelScale * viewScale;

  void _setPixelScaleOverride(double value) {
    assert(value.isFinite && value > 0.0);
    _gRenderPixelScaleOverrides[this] = value;
  }

  void _clearPixelScaleOverride() {
    _gRenderPixelScaleOverrides[this] = null;
  }
}
