part of 'package:graphx/graphx.dart';

/// Retained vector visual backed by [GGraphics].
final class GShape extends GNode {
  GShape([super.name]) {
    graphics = GGraphics._(_onGraphicsGeometryChanged, _onGraphicsPaintChanged);
    setPaintSelf(true);
  }

  late final GGraphics graphics;

  void _onGraphicsGeometryChanged() {
    invalidateBounds();
    invalidatePaint();
  }

  void _onGraphicsPaintChanged() {
    invalidatePaint();
  }

  @override
  void computeSelfBounds(GBounds out) => graphics.getBounds(out);

  @override
  bool hitTestLocal(double x, double y) => graphics.hitTestLocal(x, y);

  @override
  void paintSelf(GRenderContext context) {
    graphics._paintContext(context);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    graphics._dispose();
    super.dispose();
  }
}
