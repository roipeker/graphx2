part of 'package:graphx/src/graphx_impl.dart';

/// Raster snapshot helpers for one GraphX node subtree.
extension GNodeSnapshot on GNode {
  /// Renders this node and its descendants into a fresh owned [GTexture].
  ///
  /// Snapshot coordinates are this node's local coordinates: the node's own
  /// x/y/scale/rotation are intentionally excluded, while descendant transforms
  /// and this node's alpha, color transform, clip, mask and filters are kept.
  ///
  /// The node does not need to be attached to a [GStage]. Detached trees are
  /// rendered directly without temporary stage ownership or lifecycle changes.
  ///
  /// [area] is expressed in this node's local coordinates. When omitted, the
  /// complete effect bounds are used so blur/shadow output is not cropped.
  /// [scale] is backing-image pixels per logical GraphX unit.
  Future<GTexture> snapshot({GRect? area, double scale = 1.0}) async {
    if (isDisposed) throw StateError('Cannot snapshot a disposed node.');
    if (!scale.isFinite || scale <= 0.0) {
      throw ArgumentError.value(scale, 'scale', 'Must be finite and > 0.');
    }

    final bounds = _resolveSnapshotBounds(this, area);
    final session = GRenderSession(
      width: bounds.w,
      height: bounds.h,
      scale: scale,
    );
    try {
      return await session.render(this, originX: bounds.x, originY: bounds.y);
    } finally {
      session.dispose();
    }
  }
}

GRect _resolveSnapshotBounds(GNode node, GRect? area) {
  if (area != null) {
    if (!area.x.isFinite ||
        !area.y.isFinite ||
        !area.w.isFinite ||
        !area.h.isFinite ||
        area.w <= 0.0 ||
        area.h <= 0.0) {
      throw ArgumentError.value(area, 'area', 'Must be finite and non-empty.');
    }
    return GRect(area.x, area.y, area.w, area.h);
  }

  final bounds = node.getEffectBounds();
  if (bounds.isEmpty) {
    throw StateError('Cannot snapshot a node with empty rendered bounds.');
  }
  return GRect(bounds.x1, bounds.y1, bounds.width, bounds.height);
}

extension on GCanvasRenderer {
  Future<GTexture> _snapshotNode(
    GNode node,
    GRect bounds,
    double scale, {
    bool cacheSource = false,
  }) async {
    final pixelWidth = math.max(1, (bounds.w * scale).ceil());
    final pixelHeight = math.max(1, (bounds.h * scale).ceil());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas
      ..scale(scale, scale)
      ..translate(-bounds.x, -bounds.y);

    try {
      final context = _context;
      final sourceStage = node._stage;
      final detachedLock = sourceStage == null
          ? node._beginDetachedRenderPass()
          : null;
      final previousCacheReads = _allowRasterCache;
      _allowRasterCache = false;
      context._setPixelScaleOverride(scale);
      context._beginOffscreen(canvas, sourceStage);
      sourceStage?.beginRenderPass();
      try {
        _paintSnapshotRoot(node, context, cacheSource: cacheSource);
      } finally {
        sourceStage?.endRenderPass();
        if (detachedLock != null) node._endDetachedRenderPass(detachedLock);
        context.end();
        context._clearPixelScaleOverride();
        _allowRasterCache = previousCacheReads;
      }
    } catch (_) {
      recorder.endRecording().dispose();
      rethrow;
    }

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(pixelWidth, pixelHeight);
      return GTexture.owned(image, scale: scale);
    } finally {
      picture.dispose();
    }
  }

  void _paintSnapshotRoot(
    GNode node,
    GRenderContext context, {
    required bool cacheSource,
  }) {
    if (!node.active || !node._visible) return;

    final composite = node._composite;
    assert(
      !(composite?.directConflict ?? false),
      'GCompositeMode.direct cannot satisfy this node compositing state.',
    );

    final alpha = node._alpha;
    if (alpha <= 0.0) return;

    final color = composite?.colorTransform;
    if (color != null) context._pushColorTransform(color);

    final canvas = context.canvas;
    final clip = composite?.clip;
    if (clip != null) canvas.save();

    final previousAlpha = context.alpha;
    try {
      if (clip != null) clip._apply(canvas, node);

      if (composite?.requiresLayer ?? false) {
        _paintLayer(
          node,
          context,
          1.0,
          alpha,
          composite!,
          null,
          blendModeOverride: cacheSource ? ui.BlendMode.srcOver : null,
        );
      } else {
        context.alpha = alpha;
        _paintContents(node, context, alpha, null);
      }
    } finally {
      context.alpha = previousAlpha;
      if (clip != null) canvas.restore();
      if (color != null) context._popColorTransform();
    }
  }
}

Future<GTexture> _snapshotCacheSource(
  GNode node,
  GRect bounds,
  double scale,
) async {
  final session = GRenderSession(
    width: bounds.w,
    height: bounds.h,
    scale: scale,
  );
  try {
    return await session._render(
      node,
      originX: bounds.x,
      originY: bounds.y,
      cacheSource: true,
    );
  } finally {
    session.dispose();
  }
}
