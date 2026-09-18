part of 'package:graphx/graphx.dart';

GBounds _getNodeBounds(GNode node, GNode targetSpace, [GBounds? out]) {
  final result = out ?? GBounds.empty();
  if (identical(node, targetSpace)) {
    result.copyFrom(node._ensureLocalBounds());
    return result;
  }

  final sourceStage = node._stage;
  if (sourceStage == null || !identical(sourceStage, targetSpace._stage)) {
    throw StateError('Bounds target must belong to the same Stage.');
  }

  node._ensureWorldTransform();
  targetSpace._ensureWorldTransform();

  final source = node._worldMatrix!;
  final target = targetSpace._worldMatrix!;
  final det = target.a * target.d - target.b * target.c;
  if (det == 0.0 || !det.isFinite) {
    throw StateError('Bounds target has a singular world transform.');
  }

  final inv = 1.0 / det;
  final ia = target.d * inv;
  final ib = -target.b * inv;
  final ic = -target.c * inv;
  final id = target.a * inv;
  final itx = -(ia * target.tx + ic * target.ty);
  final ity = -(ib * target.tx + id * target.ty);

  result.setEmpty();
  _accumulateBoundsInSpace(
    node,
    result,
    ia * source.a + ic * source.b,
    ib * source.a + id * source.b,
    ia * source.c + ic * source.d,
    ib * source.c + id * source.d,
    ia * source.tx + ic * source.ty + itx,
    ib * source.tx + id * source.ty + ity,
  );
  return result;
}

GBounds _ensureNodeSelfBounds(GNode node) {
  final bounds = node._selfBoundsCache ??= GBounds.empty();
  if (!node._selfBoundsDirty) return bounds;

  bounds.setEmpty();
  node.computeSelfBounds(bounds);
  node._selfBoundsDirty = false;
  return bounds;
}

GBounds _ensureNodeLocalBounds(GNode node) {
  final bounds = node._localBoundsCache ??= GBounds.empty();
  if (!node._localBoundsDirty) return bounds;

  bounds.setEmpty();
  _accumulateBoundsInSpace(node, bounds, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
  node._localBoundsDirty = false;
  return bounds;
}

void _accumulateBoundsInSpace(
  GNode node,
  GBounds out,
  double a,
  double b,
  double c,
  double d,
  double tx,
  double ty,
) {
  final self = node._ensureSelfBounds();
  if (!self.isEmpty) {
    _includeBoundsValues(out, self, a, b, c, d, tx, ty);
  }

  final children = node._children;
  if (children == null) return;
  for (var i = 0; i < children.length; ++i) {
    final child = children[i];
    if (!child.hasLocalTransform) {
      _accumulateBoundsInSpace(child, out, a, b, c, d, tx, ty);
      continue;
    }

    final m = child.localMatrix;
    _accumulateBoundsInSpace(
      child,
      out,
      a * m.a + c * m.b,
      b * m.a + d * m.b,
      a * m.c + c * m.d,
      b * m.c + d * m.d,
      a * m.tx + c * m.ty + tx,
      b * m.tx + d * m.ty + ty,
    );
  }
}

void _includeBoundsValues(
  GBounds out,
  GBounds input,
  double a,
  double b,
  double c,
  double d,
  double tx,
  double ty,
) {
  final x1 = input.x1;
  final y1 = input.y1;
  final x2 = input.x2;
  final y2 = input.y2;
  out.includePoint(a * x1 + c * y1 + tx, b * x1 + d * y1 + ty);
  out.includePoint(a * x2 + c * y1 + tx, b * x2 + d * y1 + ty);
  out.includePoint(a * x1 + c * y2 + tx, b * x1 + d * y2 + ty);
  out.includePoint(a * x2 + c * y2 + tx, b * x2 + d * y2 + ty);
}
