// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

final Expando<_RenderGStageCapture> _gStageCaptures = Expando<_RenderGStageCapture>(
  'graphx.stageCapture',
);

/// Flutter-hosted snapshot helpers for a [GStage].
///
/// Captures the final GraphXView composition: behind portals, GraphX content,
/// and front portals. [area] uses stage/GraphXView-local logical coordinates.
extension GStageSnapshot on GStage {
  /// Captures the final GraphXView composition into an owned [GTexture].
  ///
  /// [area] selects stage-local source pixels. [transform], when supplied,
  /// maps stage coordinates into snapshot coordinates; useful for compensating
  /// an existing world transform. Null/identity uses the direct capture path.
  Future<GTexture> snapshot({
    GRect? area,
    GMatrix2? transform,
    double scale = 1.0,
  }) {
    if (!scale.isFinite || scale <= 0.0) {
      throw ArgumentError.value(scale, 'scale', 'Must be finite and > 0.');
    }
    final capture = _gStageCaptures[this];
    if (capture == null || !capture.attached) {
      throw StateError(
        'GStage.snapshot() requires this stage to be attached to GraphXView.',
      );
    }
    return capture.capture(area, transform, scale);
  }
}

final class _GStageCapture extends SingleChildRenderObjectWidget {
  const _GStageCapture({required this.stage, required super.child});

  final GStage stage;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGStageCapture(stage);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderGStageCapture renderObject,
  ) {
    renderObject.stage = stage;
  }
}

/// Tiny proxy; it becomes a repaint boundary only while snapshotting.
final class _RenderGStageCapture extends RenderProxyBox {
  _RenderGStageCapture(GStage stage) : _stage = stage {
    _gStageCaptures[stage] = this;
  }

  GStage _stage;
  int _captures = 0;

  set stage(GStage value) {
    if (identical(_stage, value)) return;
    if (identical(_gStageCaptures[_stage], this)) {
      _gStageCaptures[_stage] = null;
    }
    _stage = value;
    _gStageCaptures[value] = this;
  }

  @override
  bool get isRepaintBoundary => _captures != 0;

  Future<GTexture> capture(
    GRect? requestedArea,
    GMatrix2? transform,
    double scale,
  ) async {
    _captures++;
    if (_captures == 1) {
      markNeedsCompositingBitsUpdate();
      markNeedsPaint();
    }

    try {
      // Promotion needs one completed frame before the layer can be captured.
      await SchedulerBinding.instance.endOfFrame;
      if (!attached) {
        throw StateError('GStage detached during snapshot().');
      }

      final area = _resolveArea(requestedArea);
      final captureLayer = layer;
      if (captureLayer is! OffsetLayer) {
        throw StateError('GStage snapshot boundary is not composited.');
      }
      if (!captureLayer.supportsRasterization()) {
        throw StateError(
          'GraphXView contains non-rasterizable layers (for example a platform '
          'view) and cannot be snapshotted.',
        );
      }

      final matrix = transform;
      if (matrix == null || matrix.isIdentity) {
        final image = await captureLayer.toImage(
          ui.Rect.fromLTWH(area.x, area.y, area.w, area.h),
          pixelRatio: scale,
        );
        return GTexture.owned(image, scale: scale);
      }

      return await _captureTransformed(captureLayer, area, matrix, scale);
    } finally {
      _captures--;
      if (_captures == 0 && attached) {
        markNeedsCompositingBitsUpdate();
        markNeedsPaint();
      }
    }
  }

  Future<GTexture> _captureTransformed(
    OffsetLayer captureLayer,
    GRect area,
    GMatrix2 transform,
    double scale,
  ) async {
    final transformed = _transformRect(area, transform);
    if (transformed.w <= 0.0 || transformed.h <= 0.0) {
      throw StateError('GStage.snapshot() transform produced an empty area.');
    }

    // First capture only the requested stage region. The second raster pass is
    // paid only when a non-identity transform is explicitly requested.
    final source = await captureLayer.toImage(
      ui.Rect.fromLTWH(area.x, area.y, area.w, area.h),
      pixelRatio: scale,
    );

    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(scale, scale);
      canvas.translate(-transformed.x, -transformed.y);
      canvas.transform(
        Float64List.fromList(<double>[
          transform.a,
          transform.b,
          0.0,
          0.0,
          transform.c,
          transform.d,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          transform.tx,
          transform.ty,
          0.0,
          1.0,
        ]),
      );

      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(
          0.0,
          0.0,
          source.width.toDouble(),
          source.height.toDouble(),
        ),
        ui.Rect.fromLTWH(area.x, area.y, area.w, area.h),
        ui.Paint(),
      );

      final picture = recorder.endRecording();
      try {
        final pixelWidth = math.max(1, (transformed.w * scale).ceil());
        final pixelHeight = math.max(1, (transformed.h * scale).ceil());
        final image = await picture.toImage(pixelWidth, pixelHeight);
        return GTexture.owned(image, scale: scale);
      } finally {
        picture.dispose();
      }
    } finally {
      source.dispose();
    }
  }

  GRect _resolveArea(GRect? area) {
    final width = size.width;
    final height = size.height;
    if (width <= 0.0 || height <= 0.0) {
      throw StateError('GraphXView must complete layout before snapshot().');
    }
    if (area == null) return GRect(0.0, 0.0, width, height);
    if (!area.x.isFinite ||
        !area.y.isFinite ||
        !area.w.isFinite ||
        !area.h.isFinite ||
        area.w <= 0.0 ||
        area.h <= 0.0) {
      throw ArgumentError.value(area, 'area', 'Must be finite and non-empty.');
    }

    final left = math.max(0.0, area.x);
    final top = math.max(0.0, area.y);
    final right = math.min(width, area.x + area.w);
    final bottom = math.min(height, area.y + area.h);
    if (right <= left || bottom <= top) {
      throw ArgumentError.value(area, 'area', 'Does not intersect GraphXView.');
    }
    return GRect(left, top, right - left, bottom - top);
  }

  static GRect _transformRect(GRect rect, GMatrix2 matrix) {
    final x0 = rect.x;
    final y0 = rect.y;
    final x1 = x0 + rect.w;
    final y1 = y0 + rect.h;

    final p0x = matrix.a * x0 + matrix.c * y0 + matrix.tx;
    final p0y = matrix.b * x0 + matrix.d * y0 + matrix.ty;
    final p1x = matrix.a * x1 + matrix.c * y0 + matrix.tx;
    final p1y = matrix.b * x1 + matrix.d * y0 + matrix.ty;
    final p2x = matrix.a * x0 + matrix.c * y1 + matrix.tx;
    final p2y = matrix.b * x0 + matrix.d * y1 + matrix.ty;
    final p3x = matrix.a * x1 + matrix.c * y1 + matrix.tx;
    final p3y = matrix.b * x1 + matrix.d * y1 + matrix.ty;

    final left = math.min(math.min(p0x, p1x), math.min(p2x, p3x));
    final top = math.min(math.min(p0y, p1y), math.min(p2y, p3y));
    final right = math.max(math.max(p0x, p1x), math.max(p2x, p3x));
    final bottom = math.max(math.max(p0y, p1y), math.max(p2y, p3y));
    return GRect(left, top, right - left, bottom - top);
  }

  @override
  void dispose() {
    if (identical(_gStageCaptures[_stage], this)) {
      _gStageCaptures[_stage] = null;
    }
    super.dispose();
  }
}
