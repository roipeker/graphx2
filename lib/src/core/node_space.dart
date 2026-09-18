part of 'package:graphx/graphx.dart';

extension GNodeCoordinateSpace on GNode {
  /// Converts a point from this node's local coordinates into [target]'s local
  /// coordinates without allocating.
  ///
  /// Returns false if the nodes do not share a Stage or [target]'s world
  /// transform is singular.
  bool localToNodeInto(GNode target, double x, double y, GPoint out) {
    if (identical(this, target)) {
      out.set(x, y);
      return true;
    }

    final sourceStage = _stage;
    if (sourceStage == null || !identical(sourceStage, target._stage)) {
      return false;
    }

    _ensureWorldTransform();
    target._ensureWorldTransform();

    final source = _worldMatrix!;
    final globalX = source.a * x + source.c * y + source.tx;
    final globalY = source.b * x + source.d * y + source.ty;
    return target._worldMatrix!.inverseTransformPointInto(
      globalX,
      globalY,
      out,
    );
  }

  /// Convenience allocating form of [localToNodeInto].
  GPoint? localToNode(GNode target, double x, double y) {
    final out = GPoint();
    return localToNodeInto(target, x, y, out) ? out : null;
  }

  /// Converts a delta/vector from this node's local coordinates into [target]'s
  /// local coordinates without allocating.
  ///
  /// Translation is ignored. Returns false if the nodes do not share a Stage
  /// or [target]'s world transform is singular.
  bool localDeltaToNodeInto(GNode target, double dx, double dy, GPoint out) {
    if (identical(this, target)) {
      out.set(dx, dy);
      return true;
    }

    final sourceStage = _stage;
    if (sourceStage == null || !identical(sourceStage, target._stage)) {
      return false;
    }

    _ensureWorldTransform();
    target._ensureWorldTransform();

    final source = _worldMatrix!;
    final globalX = source.a * dx + source.c * dy;
    final globalY = source.b * dx + source.d * dy;
    return target._worldMatrix!.inverseTransformDeltaInto(
      globalX,
      globalY,
      out,
    );
  }

  /// Convenience allocating form of [localDeltaToNodeInto].
  GPoint? localDeltaToNode(GNode target, double dx, double dy) {
    final out = GPoint();
    return localDeltaToNodeInto(target, dx, dy, out) ? out : null;
  }
}
