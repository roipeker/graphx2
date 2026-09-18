part of 'package:graphx/graphx.dart';

/// Geometry-only scene hit inspection in Stage coordinates.
extension GStageHitInspection on GStage {
  /// Returns the top-most visible node at the Stage-surface point.
  ///
  /// With explicit render views, the point is resolved through the top-most
  /// enabled input view and mapped back into authoritative world coordinates.
  /// Pointer listeners and pointer routing flags do not affect this query.
  GNode? hitTest(double x, double y) {
    final views = _renderViewsOf(this)?._items;
    if (views == null || views.isEmpty) return root.hitTest(x, y);

    final view = _inputRenderViewAt(this, x, y);
    if (view == null || view.mask.isEmpty) return null;
    final world = GPoint();
    if (!view.stageToWorldInto(x, y, world)) return null;
    return _visualHitNodeAtWorld(root, world.x, world.y, view.mask);
  }

  /// Writes all visible nodes under the Stage-surface point into [out],
  /// ordered front-to-back (top-most first).
  ///
  /// Explicit render views are resolved exactly like [hitTest].
  void objectsUnderPointInto(double x, double y, List<GNode> out) {
    final views = _renderViewsOf(this)?._items;
    if (views == null || views.isEmpty) {
      root.objectsUnderPointInto(x, y, out);
      return;
    }

    out.clear();
    final view = _inputRenderViewAt(this, x, y);
    if (view == null || view.mask.isEmpty) return;
    final world = GPoint();
    if (!view.stageToWorldInto(x, y, world)) return;
    _collectVisualHitsAtWorld(root, world.x, world.y, out, view.mask);
  }

  /// Allocating convenience form of [objectsUnderPointInto].
  List<GNode> objectsUnderPoint(double x, double y) {
    final out = <GNode>[];
    objectsUnderPointInto(x, y, out);
    return out;
  }
}

extension GNodeHitInspection on GNode {
  /// Returns the top-most visible node in this subtree at a world-space point.
  ///
  /// Pointer listeners and pointer routing flags do not affect this query.
  GNode? hitTest(double stageX, double stageY) {
    if (isDisposed || !isAttached || !_active || !_visible) return null;
    return _visualHitNodeAtWorld(this, stageX, stageY, null);
  }

  /// Writes all visible nodes in this subtree under the world-space point.
  void objectsUnderPointInto(double stageX, double stageY, List<GNode> out) {
    out.clear();
    if (isDisposed || !isAttached || !_active || !_visible) return;
    _collectVisualHitsAtWorld(this, stageX, stageY, out, null);
  }

  /// Allocating convenience form of [objectsUnderPointInto].
  List<GNode> objectsUnderPoint(double stageX, double stageY) {
    final out = <GNode>[];
    objectsUnderPointInto(stageX, stageY, out);
    return out;
  }
}

GNode? _visualHitNodeAtWorld(
  GNode node,
  double worldX,
  double worldY,
  GRenderMask? renderMask,
) {
  node._ensureWorldTransform();
  final m = node._worldMatrix!;
  final det = m.a * m.d - m.b * m.c;
  if (det == 0.0 || !det.isFinite) return null;

  final inv = 1.0 / det;
  final dx = worldX - m.tx;
  final dy = worldY - m.ty;
  final localX = (m.d * dx - m.c * dy) * inv;
  final localY = (m.a * dy - m.b * dx) * inv;
  return _visualHitSubtreeLocal(node, localX, localY, renderMask);
}

void _collectVisualHitsAtWorld(
  GNode node,
  double worldX,
  double worldY,
  List<GNode> out,
  GRenderMask? renderMask,
) {
  node._ensureWorldTransform();
  final m = node._worldMatrix!;
  final det = m.a * m.d - m.b * m.c;
  if (det == 0.0 || !det.isFinite) return;

  final inv = 1.0 / det;
  final dx = worldX - m.tx;
  final dy = worldY - m.ty;
  final localX = (m.d * dx - m.c * dy) * inv;
  final localY = (m.a * dy - m.b * dx) * inv;
  _collectVisualHitsLocal(node, localX, localY, out, renderMask);
}

GNode? _visualHitSubtreeLocal(
  GNode node,
  double localX,
  double localY,
  GRenderMask? renderMask,
) {
  if (!_nodeMatchesRenderMask(node, renderMask)) return null;

  final children = node._children;
  if (children != null) {
    for (var i = children.length - 1; i >= 0; --i) {
      final child = children[i];
      if (!child._active || !child._visible) continue;
      final hit = _visualHitChild(child, localX, localY, renderMask);
      if (hit != null) return hit;
    }
  }
  return node.hitTestLocal(localX, localY) ? node : null;
}

GNode? _visualHitChild(
  GNode node,
  double parentX,
  double parentY,
  GRenderMask? renderMask,
) {
  if (!_nodeMatchesRenderMask(node, renderMask)) return null;

  var localX = parentX;
  var localY = parentY;
  if (node.hasLocalTransform) {
    final m = node.localMatrix;
    final det = m.a * m.d - m.b * m.c;
    if (det == 0.0 || !det.isFinite) return null;

    final inv = 1.0 / det;
    final dx = parentX - m.tx;
    final dy = parentY - m.ty;
    localX = (m.d * dx - m.c * dy) * inv;
    localY = (m.a * dy - m.b * dx) * inv;
  }
  return _visualHitSubtreeLocal(node, localX, localY, renderMask);
}

void _collectVisualHitsLocal(
  GNode node,
  double localX,
  double localY,
  List<GNode> out,
  GRenderMask? renderMask,
) {
  if (!_nodeMatchesRenderMask(node, renderMask)) return;

  final children = node._children;
  if (children != null) {
    for (var i = children.length - 1; i >= 0; --i) {
      final child = children[i];
      if (!child._active || !child._visible) continue;
      if (!_nodeMatchesRenderMask(child, renderMask)) continue;

      var childX = localX;
      var childY = localY;
      if (child.hasLocalTransform) {
        final m = child.localMatrix;
        final det = m.a * m.d - m.b * m.c;
        if (det == 0.0 || !det.isFinite) continue;
        final inv = 1.0 / det;
        final dx = localX - m.tx;
        final dy = localY - m.ty;
        childX = (m.d * dx - m.c * dy) * inv;
        childY = (m.a * dy - m.b * dx) * inv;
      }
      _collectVisualHitsLocal(child, childX, childY, out, renderMask);
    }
  }

  if (node.hitTestLocal(localX, localY)) out.add(node);
}

bool _nodeMatchesRenderMask(GNode node, GRenderMask? renderMask) {
  if (renderMask == null) return true;
  return node is! GRenderGroup || node._renderMask.overlaps(renderMask);
}

bool _nodeVisibleInRenderView(GNode node, GRenderView view) {
  if (!view.enabled || view.viewport.isEmpty || view.mask.isEmpty) return false;
  for (GNode? current = node; current != null; current = current._parent) {
    if (!_nodeMatchesRenderMask(current, view.mask)) return false;
  }
  return true;
}
