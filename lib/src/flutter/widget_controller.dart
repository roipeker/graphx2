part of 'package:graphx/graphx.dart';

class GraphxController<T extends GRoot> {
  T? _root;

  bool get isAttached => _root != null;

  T? get rootOrNull => _root;

  T get root => _root!;

  void _attachRoot(GRoot root) {
    if (root is! T) {
      throw StateError('GraphxController<$T> cannot bind ${root.runtimeType}.');
    }
    _root = root;
  }

  void _detachRoot(GRoot root) {
    if (!identical(_root, root)) {
      return;
    }
    _root = null;
  }
}

/// ===============================================
/// Flutter Sync object
/// used for [values] and inherited widgets.
/// ===============================================
final class GFlutterSync<T> {
  final BuildContext context;
  final T? value;

  const GFlutterSync(this.context, this.value);

  J data<J>() {
    final value = this.value;
    if (value is J) return value;
    throw StateError(
      'GraphxView supplied ${value.runtimeType}, but $J was requested.',
    );
  }
}
