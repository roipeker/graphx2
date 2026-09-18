// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Advanced planar coordinate mapping for retained nodes whose visual
/// projection is not represented by [GNode.localMatrix].
///
/// The mapping participates only in interaction geometry: pointer routing,
/// projected semantic transforms and directional-focus bounds. Normal render,
/// transform and bounds hot paths stay unchanged. Implementations should map
/// the same planar projection in both directions and return false when the
/// projection is not currently valid/visible for interaction.
abstract interface class GInteractionCoordinateMapper {
  bool mapInteractionFromParentInto(double parentX, double parentY, GPoint out);
  bool mapInteractionToParentInto(double localX, double localY, GPoint out);
}

/// Invalidates geometry derived through [GInteractionCoordinateMapper].
///
/// This is mutation-path work. Pointer hover reconciliation is demand-gated and
/// semantics invalidation is a no-op when the Stage has no semantic nodes.
extension GInteractionGeometryInvalidation on GNode {
  void invalidateInteractionGeometry() {
    _stage?._nodePointerRouter?._markSceneChanged();
    _semanticsSceneChanged(this);
  }
}

final Expando<GPoint> _gRenderViewHitScratch = Expando<GPoint>(
  'graphx.renderViewHitScratch',
);
final Expando<GPoint> _gInteractionMapScratch = Expando<GPoint>(
  'graphx.interactionMapScratch',
);

GNode? _resolveInteractiveHit(GStage stage, double stageX, double stageY) =>
    _resolvePointerHit(stage, stageX, stageY);

GNode? _resolvePointerHit(GStage stage, double stageX, double stageY) {
  final root = stage.root;
  if (root._pointerSubtreeInterest == 0) return null;

  var x = stageX;
  var y = stageY;
  var renderMaskBits = GRenderMask.all.bits;
  final views = _renderViewsOf(stage)?._items;
  if (views != null && views.isNotEmpty) {
    final view = _inputRenderViewAt(stage, stageX, stageY);
    if (view == null) return null;
    final point = _gRenderViewHitScratch[stage] ??= GPoint();
    if (!view.stageToWorldInto(stageX, stageY, point)) return null;
    x = point.x;
    y = point.y;
    renderMaskBits = view.mask.bits;
  }

  final scratch = _gInteractionMapScratch[stage] ??= GPoint();
  return _resolvePointerHitNode(root, x, y, false, renderMaskBits, scratch);
}

GNode? _resolvePointerHitNode(
  GNode node,
  double parentX,
  double parentY,
  bool ancestorInterested,
  int renderMaskBits,
  GPoint scratch,
) {
  if (!node._active || !node._visible) return null;
  final pointer = node._pointer;
  if (node is GRenderGroup &&
      (node._renderMask.bits & renderMaskBits) == 0 &&
      (pointer?._respectsRenderMask ?? true)) {
    return null;
  }
  if (pointer != null && !pointer._enabled) return null;

  final ownInterest = pointer?._hasInterest ?? false;
  if (!ancestorInterested && !ownInterest && node._pointerSubtreeInterest == 0) {
    return null;
  }

  if (!_mapInteractionFromParentInto(node, parentX, parentY, scratch)) {
    return null;
  }
  final localX = scratch.x;
  final localY = scratch.y;
  final clip = node._composite?.clip;
  if (clip != null && !_clipContains(clip, localX, localY, node)) return null;

  final canTarget = ancestorInterested || ownInterest;
  final allowChildren = pointer?._children ?? true;

  if (allowChildren) {
    final children = node._children;
    if (children != null) {
      final childAncestorInterested = ancestorInterested || ownInterest;
      for (var i = children.length - 1; i >= 0; --i) {
        final child = children[i];
        if (!childAncestorInterested && child._pointerSubtreeInterest == 0) {
          continue;
        }
        final hit = _resolvePointerHitNode(
          child,
          localX,
          localY,
          childAncestorInterested,
          renderMaskBits,
          scratch,
        );
        if (hit != null) return hit;
      }
    }

    if (canTarget && _hitTestPointerSelf(node, localX, localY)) return node;
    return null;
  }

  if (canTarget && _hitTestPointerComposite(node, localX, localY, renderMaskBits, scratch)) {
    return node;
  }
  return null;
}

bool _hitTestPointerComposite(
  GNode node,
  double localX,
  double localY,
  int renderMaskBits,
  GPoint scratch,
) {
  final area = node._pointer?._hitArea;
  if (area != null) return area.contains(localX, localY);

  if (node.hitTestLocal(localX, localY)) return true;

  final children = node._children;
  if (children == null) return false;
  for (var i = children.length - 1; i >= 0; --i) {
    if (_hitTestPointerVisualNode(
      children[i],
      localX,
      localY,
      renderMaskBits,
      scratch,
    )) {
      return true;
    }
  }
  return false;
}

bool _hitTestPointerVisualNode(
  GNode node,
  double parentX,
  double parentY,
  int renderMaskBits,
  GPoint scratch,
) {
  if (!node._active || !node._visible) return false;
  final pointer = node._pointer;
  if (node is GRenderGroup &&
      (node._renderMask.bits & renderMaskBits) == 0 &&
      (pointer?._respectsRenderMask ?? true)) {
    return false;
  }
  if (pointer != null && !pointer._enabled) return false;

  if (!_mapInteractionFromParentInto(node, parentX, parentY, scratch)) {
    return false;
  }
  final localX = scratch.x;
  final localY = scratch.y;
  final clip = node._composite?.clip;
  if (clip != null && !_clipContains(clip, localX, localY, node)) return false;

  final children = node._children;
  if (children != null) {
    for (var i = children.length - 1; i >= 0; --i) {
      if (_hitTestPointerVisualNode(
        children[i],
        localX,
        localY,
        renderMaskBits,
        scratch,
      )) {
        return true;
      }
    }
  }
  return node.hitTestLocal(localX, localY);
}

bool _mapInteractionFromParentInto(
  GNode node,
  double parentX,
  double parentY,
  GPoint out,
) {
  if (node case final GInteractionCoordinateMapper mapper) {
    return mapper.mapInteractionFromParentInto(parentX, parentY, out);
  }
  if (!node.hasLocalTransform) {
    out.set(parentX, parentY);
    return true;
  }
  final m = node.localMatrix;
  final det = m.a * m.d - m.b * m.c;
  if (det == 0.0 || !det.isFinite) return false;
  final inv = 1.0 / det;
  final dx = parentX - m.tx;
  final dy = parentY - m.ty;
  out.x = (m.d * dx - m.c * dy) * inv;
  out.y = (m.a * dy - m.b * dx) * inv;
  return true;
}

bool _mapInteractionToParentInto(
  GNode node,
  double localX,
  double localY,
  GPoint out,
) {
  if (node case final GInteractionCoordinateMapper mapper) {
    return mapper.mapInteractionToParentInto(localX, localY, out);
  }
  if (!node.hasLocalTransform) {
    out.set(localX, localY);
    return true;
  }
  node.localMatrix.transformPointInto(localX, localY, out);
  return out.x.isFinite && out.y.isFinite;
}

bool _interactionWorldToLocalInto(
  GNode node,
  double worldX,
  double worldY,
  GPoint out,
) {
  final parent = node._parent;
  if (parent == null) {
    return _mapInteractionFromParentInto(node, worldX, worldY, out);
  }
  if (!_interactionWorldToLocalInto(parent, worldX, worldY, out)) return false;
  return _mapInteractionFromParentInto(node, out.x, out.y, out);
}

bool _interactionLocalToAncestorInto(
  GNode node,
  GNode ancestor,
  double localX,
  double localY,
  GPoint out,
) {
  out.set(localX, localY);
  GNode? current = node;
  while (current != null && !identical(current, ancestor)) {
    if (!_mapInteractionToParentInto(current, out.x, out.y, out)) return false;
    current = current._parent;
  }
  return identical(current, ancestor);
}

bool _hasInteractionMapperToAncestor(GNode node, GNode ancestor) {
  GNode? current = node;
  while (current != null && !identical(current, ancestor)) {
    if (current is GInteractionCoordinateMapper) return true;
    current = current._parent;
  }
  return false;
}
