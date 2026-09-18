part of 'package:graphx/src/graphx_impl.dart';

/// Reusable Canvas renderer for painting an existing GraphX subtree inside an
/// active [GRenderContext].
///
/// This is a narrow render-boundary primitive. It does not begin or end a Stage
/// render pass and it does not change scene ownership. The supplied [node]
/// keeps its normal alpha, compositing, cache and descendant semantics.
///
/// Packages that take explicit ownership of subtree ordering/transforms (for
/// example projected 2.5D planes) can retain one painter and reuse it for every
/// frame rather than duplicating GraphX's Canvas renderer.
final class GCanvasSubtreePainter implements _GDisposable {
  final GCanvasRenderer _renderer = GCanvasRenderer();
  bool _disposed = false;

  void paint(GRenderContext context, GNode node, {double? parentAlpha}) {
    if (_disposed) {
      throw StateError('Canvas subtree painter is disposed.');
    }

    final contextStage = context._stage;
    final nodeStage = node._stage;
    if (!identical(contextStage, nodeStage)) {
      throw StateError(
        'Canvas subtree painter cannot cross Stage ownership boundaries.',
      );
    }

    _renderer._paintNode(
      node,
      context,
      parentAlpha ?? context.alpha,
      context._renderStats,
    );
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _renderer.dispose();
  }
}
