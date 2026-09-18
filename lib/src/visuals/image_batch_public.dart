part of 'package:graphx/src/graphx_impl.dart';

/// Public ownership/introspection for lightweight batch instances.
extension GImageInstanceOwnership on GImageInstance {
  /// The batch currently owning this instance, or null after removal/disposal.
  ///
  /// Instances remain deliberately lightweight and are not scene nodes. This
  /// exposes existing ownership without adding lifecycle/listener state to each
  /// instance, which lets optional packages bind stage-local behavior safely.
  GImageBatch? get batch => _alive ? _batch : null;
}
