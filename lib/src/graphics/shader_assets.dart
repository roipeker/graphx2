// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

extension GShaderAssets on GAssets {
  /// Loads and caches a build-time fragment program asset.
  ///
  /// Flutter's current Canvas backend only supports compiled shader assets;
  /// runtime source/byte loading is intentionally not emulated here.
  Future<GShader> shader(String assetPath, {bool cache = true}) {
    return load<GShader>(
      ('shader', assetPath),
      () async => GShader._(assetPath, await ui.FragmentProgram.fromAsset(assetPath)),
      cache: cache,
    );
  }
}
