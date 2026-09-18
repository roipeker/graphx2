// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Explicit sampled bounds queries for retained Graphics geometry.
///
/// Canonical [GShape] bounds remain the cheap conservative native path bounds.
/// Nothing here runs while authoring or painting unless the caller asks for it.
extension GGraphicsApproximateBounds on GGraphics {
  /// Computes a tighter sampled approximation of the currently painted
  /// geometry into [out].
  ///
  /// [sampleStep] is the approximate distance in local-space units between
  /// path samples. Smaller values cost more. Stroke padding remains
  /// conservative.
  ///
  /// This query is intentionally uncached and never participates in canonical
  /// node bounds, invalidation, or the Graphics drawing hot path.
  void computeApproximateBounds(
    GBounds out, {
    double sampleStep = _gDefaultPathSampleStep,
  }) {
    _validatePathSampleStep(sampleStep);
    out.setEmpty();

    for (var i = 0; i < _batches.length; ++i) {
      final batch = _batches[i];
      if (!batch.paints) continue;
      _samplePathGeometry(
        batch.path,
        sampleStep,
        bounds: out,
        boundsPad: batch.stroke?.boundsPad ?? 0.0,
      );
    }
  }
}
