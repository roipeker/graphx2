part of 'package:graphx/src/graphx_impl.dart';

/// Shared GraphX/GraphX runtime state whose lifetime may span many stages.
///
/// Keep this intentionally small. Only facilities that are meaningfully shared
/// across stages belong here.
final class GRuntime implements _GDisposable {
  GRuntime({GAssetUrlLoader? urlLoader})
    : assets = GAssets(urlLoader: urlLoader) {
    if (!kReleaseMode) {
      _gInspectorResourcesRuntime.ensureRegistered();
      _gInspectorResourceReferencesRuntime.ensureRegistered();
      _gInspectorRenderingRuntime.ensureRegistered();
    }
  }

  final GAssets assets;

  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    assets.dispose();
  }
}
