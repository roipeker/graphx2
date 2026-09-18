part of 'package:graphx/graphx.dart';

/// Rectangular programmable visual backed by a [GShaderInstance].
///
/// Geometry is explicit: shaders and sampler textures never infer node size.
/// Shader animation is caller-driven; this node only keeps the optional
/// `graphx_size` semantic in sync with its geometry.
final class GShaderNode extends GNode {
  GShaderNode(
    this.shader, {
    double width = 0.0,
    double height = 0.0,
    String? name,
  }) : _width = width,
       _height = height,
       super(name) {
    if (width < 0 || height < 0 || !width.isFinite || !height.isFinite) {
      throw ArgumentError('Shader node size must be finite and non-negative.');
    }
    setPaintSelf(true);
    shader._listen(_shaderChanged);
    _size = shader._tryVec2('graphx_size');
    _size?.set(width, height);
  }

  final GShaderInstance shader;
  final Paint _paint = Paint();
  late final GShaderVec2? _size;
  double _width;
  double _height;

  double get width => _width;
  set width(double value) => resize(value, _height);

  double get height => _height;
  set height(double value) => resize(_width, value);

  void resize(double width, double height) {
    if (!width.isFinite || !height.isFinite || width < 0 || height < 0) {
      throw ArgumentError('Shader node size must be finite and non-negative.');
    }
    if (_width == width && _height == height) return;
    _width = width;
    _height = height;
    _size?.set(width, height);
    invalidateBounds();
    invalidatePaint();
  }

  @override
  void computeSelfBounds(GBounds out) {
    if (_width == 0 || _height == 0) {
      out.setEmpty();
    } else {
      out.setXYWH(0, 0, _width, _height);
    }
  }

  @override
  void paintSelf(GRenderContext context) {
    if (_width <= 0 || _height <= 0) return;
    _paint
      ..shader = shader._nativeShader
      ..color = const Color(0xffffffff)
      ..blendMode = BlendMode.srcOver
      ..colorFilter = context.hasColorTransform
          ? context._effectiveColorFilter
          : null;
    context.canvas.drawRect(Rect.fromLTWH(0, 0, _width, _height), _paint);
  }

  void _shaderChanged() => invalidatePaint();

  @override
  void dispose() {
    shader._unlisten(_shaderChanged);
    _paint.shader = null;
    super.dispose();
  }
}
