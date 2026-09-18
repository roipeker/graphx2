// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

typedef GraphXSceneBuilder = void Function(GRoot root);

/// Small root facade for callback prototype scenes.
final class GCallbackRoot extends GRoot {
  GCallbackRoot(this.builder);

  final GraphXSceneBuilder builder;

  @override
  void attached() {
    builder(this);
  }
}
