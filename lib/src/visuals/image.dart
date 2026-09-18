// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Scene node that renders one [GTexture].
final class GImage extends GNode {
  GImage([GTexture? texture]) {
    _render.texture = texture;
    setPaintSelf(true);
  }

  final _GImageRenderState _render = _GImageRenderState();

  GTexture? get texture => _render.texture;
  set texture(GTexture? value) {
    if (identical(_render.texture, value)) return;
    _render.texture = value;
    invalidateBounds();
    invalidatePaint();
  }

  double get width => _render.width;
  double get height => _render.height;

  ui.FilterQuality get filterQuality => _render.filterQuality;
  set filterQuality(ui.FilterQuality value) {
    if (_render.filterQuality == value) return;
    _render.filterQuality = value;
    invalidatePaint();
  }

  @override
  void computeSelfBounds(GBounds out) {
    if (_render.texture == null) {
      out.setEmpty();
      return;
    }
    out.setXYWH(0.0, 0.0, _render.width, _render.height);
  }

  @override
  void paintSelf(GRenderContext context) => _render.paint(context);
}

/// Canvas-specific resolved texture state shared by static and animated images.
/// Texture geometry is immutable, so source/destination rectangles are rebuilt
/// only when the displayed texture changes.
final class _GImageRenderState {
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.low;

  GTexture? _texture;
  ui.Rect _src = ui.Rect.zero;
  ui.Rect _dst = ui.Rect.zero;
  bool _rotated = false;
  double _rotateX = 0.0;
  double _rotateY = 0.0;
  double _width = 0.0;
  double _height = 0.0;
  int _alphaByte = -1;
  ColorFilter? _colorFilter;

  GTexture? get texture => _texture;
  set texture(GTexture? value) {
    if (identical(_texture, value)) return;
    if (value?.isDisposed ?? false) {
      throw StateError('Cannot assign a disposed GTexture.');
    }
    _texture = value;
    _resolve(value);
  }

  double get width => _width;
  double get height => _height;

  ui.FilterQuality get filterQuality => _paint.filterQuality;
  set filterQuality(ui.FilterQuality value) => _paint.filterQuality = value;

  void _resolve(GTexture? texture) {
    if (texture == null) {
      _src = ui.Rect.zero;
      _dst = ui.Rect.zero;
      _rotated = false;
      _rotateX = _rotateY = 0.0;
      _width = _height = 0.0;
      return;
    }

    final frame = texture.frame;
    final scale = texture.scale;
    _width = texture.width;
    _height = texture.height;
    _src = ui.Rect.fromLTWH(
      frame.region.x,
      frame.region.y,
      frame.region.w,
      frame.region.h,
    );
    _rotated = frame.rotated;

    if (!_rotated) {
      _dst = ui.Rect.fromLTWH(
        frame.offsetX / scale,
        frame.offsetY / scale,
        frame.region.w / scale,
        frame.region.h / scale,
      );
      _rotateX = _rotateY = 0.0;
      return;
    }

    _dst = ui.Rect.fromLTWH(
      0.0,
      0.0,
      frame.region.w / scale,
      frame.region.h / scale,
    );
    _rotateX = frame.offsetX / scale;
    _rotateY = (frame.offsetY + frame.region.w) / scale;
  }

  void paint(GRenderContext context) {
    final texture = _texture;
    if (texture == null) return;
    if (texture.isDisposed) {
      assert(false, 'A GTexture referenced by a live image was disposed.');
      return;
    }

    final alpha = context.alpha;
    if (alpha <= 0.0) return;

    if (context.hasColorTransform) {
      final filter = context._effectiveColorFilter;
      if (!identical(_colorFilter, filter) || _alphaByte != 255) {
        _colorFilter = filter;
        _alphaByte = 255;
        _paint
          ..color = const ui.Color(0xffffffff)
          ..colorFilter = filter;
      }
    } else {
      if (_colorFilter != null) {
        _colorFilter = null;
        _paint.colorFilter = null;
      }
      final alphaByte = (alpha * 255.0).round().clamp(0, 255).toInt();
      if (_alphaByte != alphaByte) {
        _alphaByte = alphaByte;
        _paint.color = ui.Color.fromARGB(alphaByte, 255, 255, 255);
      }
    }

    final canvas = context.canvas;
    if (!_rotated) {
      canvas.drawImageRect(texture.image, _src, _dst, _paint);
      return;
    }

    canvas.save();
    try {
      canvas.translate(_rotateX, _rotateY);
      canvas.rotate(-math.pi / 2.0);
      canvas.drawImageRect(texture.image, _src, _dst, _paint);
    } finally {
      canvas.restore();
    }
  }
}
