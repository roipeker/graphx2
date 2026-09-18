part of 'package:graphx/graphx.dart';

typedef GraphxSceneBuilder = void Function(GRoot root);

/// Small root facade for callback prototype scenes.
final class GCallbackRoot extends GRoot {
  GCallbackRoot(this.builder);

  final GraphxSceneBuilder builder;

  @override
  void attached() {
    builder(this);
  }
}
