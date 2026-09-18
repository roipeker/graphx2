part of 'package:graphx/src/graphx_impl.dart';

/// Allocation-aware access to a node's own untransformed geometry.
///
/// Unlike [GNode.getLocalBounds], self bounds do not include descendants or any
/// node transform. They are the bounds authored by [GNode.computeSelfBounds].
/// Retained systems such as layout can therefore consume intrinsic geometry
/// without coupling themselves to visual subtree transforms.
extension GNodeSelfBoundsExtension on GNode {
  GBounds getSelfBounds([GBounds? out]) {
    final result = out ?? GBounds.empty();
    result.copyFrom(_ensureSelfBounds());
    return result;
  }

  GBounds get selfBounds => getSelfBounds();
}
