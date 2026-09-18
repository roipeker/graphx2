part of 'package:graphx/src/graphx_impl.dart';

/// Reusable offscreen rendering surface for one logical output size.
///
/// A render session owns renderer/backend scratch state, not scene lifecycle.
/// It can render detached trees directly, or render a [GStage] while the Stage
/// independently owns updates, plugins, viewport state and lifecycle.
///
/// [scale] is backing-image pixels per logical GraphX unit. The rendered
/// texture always covers [width] × [height] logical units. [originX]/[originY]
/// select which node-local coordinate maps to the output's top-left corner.
final class GRenderSession implements _GDisposable {
  GRenderSession({
    required double width,
    required double height,
    this.scale = 1.0,
  }) : width = _validateExtent(width, 'width'),
       height = _validateExtent(height, 'height') {
    if (!scale.isFinite || scale <= 0.0) {
      throw ArgumentError.value(scale, 'scale', 'Must be finite and > 0.');
    }
  }

  final double width;
  final double height;
  final double scale;

  final GCanvasRenderer _renderer = GCanvasRenderer();
  bool _disposed = false;
  bool _recording = false;

  /// Renders [node] and its descendants into a fresh owned [GTexture].
  ///
  /// The node's own positioning transform is intentionally excluded, matching
  /// [GNodeSnapshot.snapshot]. Descendant transforms and the root node's visual
  /// state (alpha, color transform, clip, mask and filters) are preserved.
  /// Raster-cache reads and viewport culling are bypassed so this is a complete
  /// subtree capture rather than a hosted Stage frame.
  ///
  /// The node may be detached. When it belongs to a [GStage], the Stage remains
  /// the runtime/lifecycle owner; this session only performs rendering.
  Future<GTexture> render(
    GNode node, {
    double originX = 0.0,
    double originY = 0.0,
  }) {
    return _render(
      node,
      originX: originX,
      originY: originY,
      cacheSource: false,
    );
  }

  /// Renders one full Stage frame without requiring a [GStageHost].
  ///
  /// This uses the normal Stage renderer path, including viewport culling,
  /// retained raster-cache reads and render diagnostics. The Stage remains the
  /// sole runtime owner and may be driven manually through [GStage.tick].
  /// Rendering does not consume the Stage's host paint-request flag.
  Future<GTexture> renderStage(GStage stage) async {
    _checkAlive();
    if (stage.isDisposed) throw StateError('Cannot render a disposed Stage.');
    if (!stage.isMounted) throw StateError('Cannot render an unmounted Stage.');
    if (!stage.root.isAttached) {
      throw StateError('Cannot render a Stage before its root is attached.');
    }

    final pixelWidth = math.max(1, (width * scale).ceil());
    final pixelHeight = math.max(1, (height * scale).ceil());
    final recorder = ui.PictureRecorder();

    _beginRecording();
    try {
      final canvas = ui.Canvas(recorder)..scale(scale, scale);
      final context = _renderer._context;
      context._setPixelScaleOverride(scale);
      try {
        _renderer.render(canvas, stage);
      } finally {
        context._clearPixelScaleOverride();
      }
    } catch (_) {
      recorder.endRecording().dispose();
      rethrow;
    } finally {
      _endRecording();
    }

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(pixelWidth, pixelHeight);
      return GTexture.owned(image, scale: scale);
    } finally {
      picture.dispose();
    }
  }

  Future<GTexture> _render(
    GNode node, {
    required double originX,
    required double originY,
    required bool cacheSource,
  }) {
    _checkAlive();
    if (node.isDisposed) {
      throw StateError('Cannot render a disposed node.');
    }
    if (!originX.isFinite || !originY.isFinite) {
      throw ArgumentError('Render origin must be finite.');
    }

    _beginRecording();
    try {
      return _renderer._snapshotNode(
        node,
        GRect(originX, originY, width, height),
        scale,
        cacheSource: cacheSource,
      );
    } finally {
      _endRecording();
    }
  }

  static double _validateExtent(double value, String name) {
    if (!value.isFinite || value <= 0.0) {
      throw ArgumentError.value(value, name, 'Must be finite and > 0.');
    }
    return value;
  }

  void _checkAlive() {
    if (_disposed) throw StateError('Render session is disposed.');
  }

  void _beginRecording() {
    if (_recording) {
      throw StateError('Render session cannot recursively record a scene.');
    }
    _recording = true;
  }

  void _endRecording() {
    assert(_recording);
    _recording = false;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    if (_recording) {
      throw StateError('Cannot dispose a render session while rendering.');
    }
    _disposed = true;
    _renderer.dispose();
  }
}
