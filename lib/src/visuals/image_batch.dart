part of 'package:graphx/graphx.dart';

/// One scene node that renders many lightweight [GTexture] instances.
///
/// Instances are intentionally not [GNode]s. They write directly into packed
/// atlas buffers while this batch retains normal node transform/compositing
/// semantics.
final class GImageBatch extends GNode {
  GImageBatch({int capacity = 64}) {
    if (capacity < 0) {
      throw ArgumentError.value(capacity, 'capacity', 'must be >= 0');
    }
    _capacity = capacity;
    final floatCapacity = capacity * 4;
    _transforms = _GFloat32Buffer.growable(
      capacity: floatCapacity,
      length: floatCapacity,
    );
    _rects = _GFloat32Buffer.growable(
      capacity: floatCapacity,
      length: floatCapacity,
    );
    _textures = List<GTexture?>.filled(capacity, null);
    setPaintSelf(true);
  }

  late final _GFloat32Buffer _transforms;
  late final _GFloat32Buffer _rects;
  Int32List? _colors;
  late List<GTexture?> _textures;
  final List<GImageInstance> _instances = <GImageInstance>[];
  final List<_GImageBatchRun> _runs = <_GImageBatchRun>[];
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.low;

  int _count = 0;
  int _capacity = 0;
  int _alphaByte = -1;
  bool _runsDirty = true;
  bool _paintInvalidated = false;
  bool _boundsInvalidated = false;

  int get length => _count;
  bool get isEmpty => _count == 0;
  bool get isNotEmpty => _count != 0;
  int get capacity => _capacity;
  bool get usesInstanceColors => _colors != null;

  ui.FilterQuality get filterQuality => _paint.filterQuality;
  set filterQuality(ui.FilterQuality value) {
    if (_paint.filterQuality == value) return;
    _paint.filterQuality = value;
    _markPaintChanged();
  }

  GImageInstance operator [](int index) => _instances[index];

  GImageInstance add(
    GTexture texture, {
    double x = 0.0,
    double y = 0.0,
    double rotation = 0.0,
    double scale = 1.0,
    double pivotX = 0.0,
    double pivotY = 0.0,
    double alpha = 1.0,
    ui.Color color = const ui.Color(0xffffffff),
  }) {
    _validateTexture(texture);
    _validateTransform(x, y, rotation, scale);
    _validatePivot(pivotX, pivotY);
    _validateAlpha(alpha);
    _ensureCapacity(_count + 1);

    final instance = GImageInstance._(
      this,
      _count,
      texture,
      x,
      y,
      rotation,
      scale,
      pivotX,
      pivotY,
      alpha,
      color,
    );
    _instances.add(instance);
    _textures[_count] = texture;
    _count++;
    _writeRect(instance._index, texture);
    _writeTransform(instance);
    if (alpha != 1.0 || color != const ui.Color(0xffffffff)) {
      _ensureColors();
      _writeColor(instance);
    } else {
      final colors = _colors;
      if (colors != null) colors[instance._index] = 0xffffffff;
    }
    _runsDirty = true;
    _markGeometryChanged();
    return instance;
  }

  void remove(GImageInstance instance) {
    if (!identical(instance._batch, this) || !instance._alive) {
      throw StateError('Image instance does not belong to this batch.');
    }
    _removeAt(instance._index);
  }

  GImageInstance removeAt(int index) {
    RangeError.checkValidIndex(index, _instances, 'index');
    return _removeAt(index);
  }

  void clear() {
    if (_count == 0) return;
    for (final instance in _instances) instance._detach();
    _instances.clear();
    _textures.fillRange(0, _count, null);
    _count = 0;
    _runs.clear();
    _runsDirty = false;
    _markGeometryChanged();
  }

  GImageInstance _removeAt(int index) {
    final removed = _instances[index];
    if (index + 1 < _count) {
      final transforms = _transforms.data;
      final rects = _rects.data;
      transforms.setRange(
        index * 4,
        (_count - 1) * 4,
        transforms,
        (index + 1) * 4,
      );
      rects.setRange(index * 4, (_count - 1) * 4, rects, (index + 1) * 4);
      final colors = _colors;
      if (colors != null) {
        colors.setRange(index, _count - 1, colors, index + 1);
      }
      _textures.setRange(index, _count - 1, _textures, index + 1);
      for (var i = index + 1; i < _count; ++i) {
        _instances[i]._index = i - 1;
      }
    }
    _count--;
    _textures[_count] = null;
    _instances.removeAt(index);
    removed._detach();
    _runsDirty = true;
    _markGeometryChanged();
    return removed;
  }

  void _setTexture(GImageInstance instance, GTexture texture) {
    _validateTexture(texture);
    if (identical(instance._texture, texture)) return;
    instance._texture = texture;
    _textures[instance._index] = texture;
    _writeRect(instance._index, texture);
    _writeTransform(instance);
    _runsDirty = true;
    _markGeometryChanged();
  }

  void _setPosition(GImageInstance instance, double x, double y) {
    if (instance._x == x && instance._y == y) return;
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Image instance position must be finite.');
    }
    instance._x = x;
    instance._y = y;
    _writeTransform(instance);
    _markGeometryChanged();
  }

  void _setRotation(GImageInstance instance, double value) {
    if (instance._rotation == value) return;
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'rotation', 'must be finite');
    }
    instance._rotation = value;
    _writeTransform(instance);
    _markGeometryChanged();
  }

  void _setScale(GImageInstance instance, double value) {
    if (instance._scale == value) return;
    if (!value.isFinite || value < 0.0) {
      throw ArgumentError.value(value, 'scale', 'must be finite and >= 0');
    }
    instance._scale = value;
    _writeTransform(instance);
    _markGeometryChanged();
  }

  void _setPivot(GImageInstance instance, double x, double y) {
    if (instance._pivotX == x && instance._pivotY == y) return;
    _validatePivot(x, y);
    instance._pivotX = x;
    instance._pivotY = y;
    _writeTransform(instance);
    _markGeometryChanged();
  }

  void _setAlpha(GImageInstance instance, double value) {
    _validateAlpha(value);
    if (instance._alpha == value) return;
    instance._alpha = value;
    _ensureColors();
    _writeColor(instance);
    _markPaintChanged();
  }

  void _setColor(GImageInstance instance, ui.Color value) {
    if (instance._color == value) return;
    instance._color = value;
    _ensureColors();
    _writeColor(instance);
    _markPaintChanged();
  }

  void _setTransform(
    GImageInstance instance,
    double x,
    double y,
    double rotation,
    double scale,
  ) {
    _validateTransform(x, y, rotation, scale);
    if (instance._x == x &&
        instance._y == y &&
        instance._rotation == rotation &&
        instance._scale == scale) {
      return;
    }
    instance._x = x;
    instance._y = y;
    instance._rotation = rotation;
    instance._scale = scale;
    _writeTransform(instance);
    _markGeometryChanged();
  }

  void _writeRect(int index, GTexture texture) {
    final region = texture.frame.region;
    final rects = _rects.data;
    final base = index * 4;
    rects[base] = region.x;
    rects[base + 1] = region.y;
    rects[base + 2] = region.x + region.w;
    rects[base + 3] = region.y + region.h;
  }

  void _writeTransform(GImageInstance instance) {
    final texture = instance._texture;
    final frame = texture.frame;
    final rotation = instance._rotation;
    final scale = instance._scale;
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);
    final invTextureScale = 1.0 / texture.scale;
    final drawScale = scale * invTextureScale;

    // A rotated atlas frame is exactly a -90° basis change. Reuse the one
    // sin/cos pair instead of evaluating trig a second time per mutation.
    final scos = (frame.rotated ? sin : cos) * drawScale;
    final ssin = (frame.rotated ? -cos : sin) * drawScale;

    final offsetX = frame.offsetX * invTextureScale - instance._pivotX;
    final offsetY =
        (frame.rotated ? frame.offsetY + frame.region.w : frame.offsetY) *
            invTextureScale -
        instance._pivotY;
    final scaledCos = cos * scale;
    final scaledSin = sin * scale;
    final transforms = _transforms.data;
    final base = instance._index * 4;
    transforms[base] = scos;
    transforms[base + 1] = ssin;
    transforms[base + 2] =
        instance._x + scaledCos * offsetX - scaledSin * offsetY;
    transforms[base + 3] =
        instance._y + scaledSin * offsetX + scaledCos * offsetY;
  }

  void _ensureColors() {
    if (_colors != null) return;
    final colors = Int32List(_capacity);
    colors.fillRange(0, _count, 0xffffffff);
    _colors = colors;
    _runsDirty = true;
  }

  void _writeColor(GImageInstance instance) {
    final source = instance._color;
    final color = source.colorSpace == ui.ColorSpace.sRGB
        ? source
        : source.withValues(colorSpace: ui.ColorSpace.sRGB);
    final a = _colorByte(color.a * instance._alpha);
    final r = _colorByte(color.r);
    final g = _colorByte(color.g);
    final b = _colorByte(color.b);
    _colors![instance._index] = (a << 24) | (r << 16) | (g << 8) | b;
  }

  static int _colorByte(double value) =>
      (value * 255.0).round().clamp(0, 255).toInt();

  void _ensureCapacity(int required) {
    if (required <= _capacity) return;
    var next = _capacity == 0 ? 4 : _capacity;
    while (next < required) next *= 2;

    final textures = List<GTexture?>.filled(next, null);
    if (_count > 0) {
      textures.setRange(0, _count, _textures);
    }
    final oldColors = _colors;
    if (oldColors != null) {
      final colors = Int32List(next);
      colors.setRange(0, _count, oldColors);
      _colors = colors;
    }

    final floatCapacity = next * 4;
    _transforms.reserve(floatCapacity);
    _transforms.setLength(floatCapacity);
    _rects.reserve(floatCapacity);
    _rects.setLength(floatCapacity);
    _textures = textures;
    _capacity = next;
    _runsDirty = true;
  }

  void _markGeometryChanged() {
    if (!_boundsInvalidated) {
      _boundsInvalidated = true;
      invalidateBounds();
    }
    _markPaintChanged();
  }

  void _markPaintChanged() {
    if (_paintInvalidated) return;
    _paintInvalidated = true;
    invalidatePaint();
  }

  void _rebuildRuns() {
    _runs.clear();
    if (_count == 0) {
      _runsDirty = false;
      return;
    }
    final transforms = _transforms.data;
    final rects = _rects.data;
    var start = 0;
    var image = _textures[0]!.image;
    for (var i = 1; i <= _count; ++i) {
      final nextImage = i == _count ? null : _textures[i]!.image;
      if (i < _count && identical(image, nextImage)) continue;
      _runs.add(
        _GImageBatchRun(
          image,
          Float32List.sublistView(transforms, start * 4, i * 4),
          Float32List.sublistView(rects, start * 4, i * 4),
          _colors == null ? null : Int32List.sublistView(_colors!, start, i),
        ),
      );
      if (i < _count) {
        start = i;
        image = nextImage!;
      }
    }
    _runsDirty = false;
  }

  @override
  void computeSelfBounds(GBounds out) {
    _boundsInvalidated = false;
    out.setEmpty();
    for (final instance in _instances) {
      final w = instance._texture.width;
      final h = instance._texture.height;
      final x1 = -instance._pivotX;
      final y1 = -instance._pivotY;
      final x2 = w - instance._pivotX;
      final y2 = h - instance._pivotY;
      final cos = math.cos(instance._rotation) * instance._scale;
      final sin = math.sin(instance._rotation) * instance._scale;
      final x = instance._x;
      final y = instance._y;
      out.includePoint(x + cos * x1 - sin * y1, y + sin * x1 + cos * y1);
      out.includePoint(x + cos * x2 - sin * y1, y + sin * x2 + cos * y1);
      out.includePoint(x + cos * x1 - sin * y2, y + sin * x1 + cos * y2);
      out.includePoint(x + cos * x2 - sin * y2, y + sin * x2 + cos * y2);
    }
  }

  @override
  void paintSelf(GRenderContext context) {
    _paintInvalidated = false;
    if (_count == 0 || context.alpha <= 0.0) return;
    if (_runsDirty) _rebuildRuns();
    if (context.hasColorTransform) {
      _paint
        ..color = const ui.Color(0xffffffff)
        ..colorFilter = context._effectiveColorFilter;
      _alphaByte = 255;
    } else {
      _paint.colorFilter = null;
      final alphaByte = (context.alpha * 255.0).round().clamp(0, 255).toInt();
      if (_alphaByte != alphaByte) {
        _alphaByte = alphaByte;
        _paint.color = ui.Color.fromARGB(alphaByte, 255, 255, 255);
      }
    }
    for (final run in _runs) {
      context.canvas.drawRawAtlas(
        run.image,
        run.transforms,
        run.rects,
        run.colors,
        run.colors == null ? null : ui.BlendMode.modulate,
        null,
        _paint,
      );
    }
  }

  @override
  void dispose() {
    if (isDisposed) return;
    for (final instance in _instances) instance._detach();
    _instances.clear();
    _runs.clear();
    super.dispose();
  }

  static void _validateTexture(GTexture texture) {
    if (texture.isDisposed) {
      throw StateError('Cannot add a disposed GTexture to GImageBatch.');
    }
  }

  static void _validateTransform(
    double x,
    double y,
    double rotation,
    double scale,
  ) {
    if (!x.isFinite || !y.isFinite || !rotation.isFinite) {
      throw ArgumentError('Image instance transform values must be finite.');
    }
    if (!scale.isFinite || scale < 0.0) {
      throw ArgumentError.value(scale, 'scale', 'must be finite and >= 0');
    }
  }

  static void _validatePivot(double x, double y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Image instance pivot must be finite.');
    }
  }

  static void _validateAlpha(double value) {
    if (!value.isFinite || value < 0.0 || value > 1.0) {
      throw ArgumentError.value(
        value,
        'alpha',
        'must be finite and between 0 and 1',
      );
    }
  }
}

/// Lightweight textured element owned by a [GImageBatch].
///
/// This is deliberately not a scene node. Use [GImage] when an image needs
/// independent children, pointer routing, filters, masks, or node lifecycle.
final class GImageInstance {
  GImageInstance._(
    this._batch,
    this._index,
    this._texture,
    this._x,
    this._y,
    this._rotation,
    this._scale,
    this._pivotX,
    this._pivotY,
    this._alpha,
    this._color,
  );

  GImageBatch? _batch;
  int _index;
  GTexture _texture;
  double _x;
  double _y;
  double _rotation;
  double _scale;
  double _pivotX;
  double _pivotY;
  double _alpha;
  ui.Color _color;
  bool _alive = true;

  bool get isAttached => _alive;

  GTexture get texture => _texture;
  set texture(GTexture value) => _owner._setTexture(this, value);

  double get x => _x;
  set x(double value) => _owner._setPosition(this, value, _y);

  double get y => _y;
  set y(double value) => _owner._setPosition(this, _x, value);

  double get rotation => _rotation;
  set rotation(double value) => _owner._setRotation(this, value);

  double get scale => _scale;
  set scale(double value) => _owner._setScale(this, value);

  double get pivotX => _pivotX;
  set pivotX(double value) => _owner._setPivot(this, value, _pivotY);

  double get pivotY => _pivotY;
  set pivotY(double value) => _owner._setPivot(this, _pivotX, value);

  double get alpha => _alpha;
  set alpha(double value) => _owner._setAlpha(this, value);

  ui.Color get color => _color;
  set color(ui.Color value) => _owner._setColor(this, value);

  void setPosition(double x, double y) => _owner._setPosition(this, x, y);

  void setPivot(double x, double y) => _owner._setPivot(this, x, y);

  void setTransform({
    required double x,
    required double y,
    double rotation = 0.0,
    double scale = 1.0,
  }) => _owner._setTransform(this, x, y, rotation, scale);

  void remove() => _owner.remove(this);

  GImageBatch get _owner {
    final owner = _batch;
    if (!_alive || owner == null) {
      throw StateError('GImageInstance is no longer attached to a batch.');
    }
    return owner;
  }

  void _detach() {
    _alive = false;
    _batch = null;
    _index = -1;
  }
}

final class _GImageBatchRun {
  const _GImageBatchRun(this.image, this.transforms, this.rects, this.colors);

  final ui.Image image;
  final Float32List transforms;
  final Float32List rects;
  final Int32List? colors;
}
