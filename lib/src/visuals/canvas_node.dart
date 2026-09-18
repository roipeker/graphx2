// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

typedef GCanvasPainter = void Function(GRenderContext context);

class GCanvasNode extends GNode {
  GCanvasNode([GCanvasPainter? painter]) : _painter = painter {
    _paintSelf = painter != null;
  }

  GCanvasPainter? _painter;

  GCanvasPainter? get painter => _painter;

  set painter(GCanvasPainter? value) {
    if (identical(_painter, value)) return;
    _painter = value;
    _paintSelf = value != null;
    if (isAttached) {
      stage.requestPaint();
    }
  }

  @override
  void paintSelf(GRenderContext context) {
    _painter?.call(context);
  }
}
