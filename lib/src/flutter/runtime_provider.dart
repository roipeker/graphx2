part of 'package:graphx/src/graphx_impl.dart';

/// Makes one shared [GRuntime] available to descendant [GraphXView] instances.
class GRuntimeProvider extends InheritedWidget {
  const GRuntimeProvider({
    super.key,
    required this.runtime,
    required super.child,
  });

  final GRuntime runtime;

  static GRuntime? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GRuntimeProvider>()
        ?.runtime;
  }

  static GRuntime of(BuildContext context) {
    final runtime = maybeOf(context);
    if (runtime == null) {
      throw StateError('No GRuntimeProvider found in the widget tree.');
    }
    return runtime;
  }

  @override
  bool updateShouldNotify(GRuntimeProvider oldWidget) {
    return !identical(oldWidget.runtime, runtime);
  }
}
