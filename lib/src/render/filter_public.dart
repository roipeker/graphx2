part of 'package:graphx/graphx.dart';

/// Public filter ownership/introspection needed by plugin packages.
extension GFilterOwnership on GFilter {
  /// The live node currently using this filter, or null when unattached.
  ///
  /// A filter still belongs to at most one live node. This getter exposes that
  /// existing contract without making ownership mutable outside GraphX.
  GNode? get owner {
    final value = _owner?.target;
    if (value == null || value.isDisposed) return null;
    return value;
  }
}
