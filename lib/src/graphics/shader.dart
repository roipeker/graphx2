// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Low-level Canvas shader accepted by [GGraphics.beginPaintShaderFill].
typedef GPaintShader = ui.Shader;

/// Reusable compiled fragment program.
///
/// Load through [GAssets.shader], then create cheap mutable [GShaderInstance]s.
final class GShader {
  GShader._(this.asset, this._program);

  final String asset;
  final ui.FragmentProgram _program;

  /// Creates independent mutable bindings for this compiled program.
  ///
  /// [samplers] maps sampler names to their declaration-order sampler index.
  /// Supplying it keeps named texture mutation portable to backends where
  /// Flutter's `getImageSampler(name)` convenience API is unavailable.
  GShaderInstance instance({Map<String, int> samplers = const {}}) =>
      GShaderInstance._(this, _program.fragmentShader(), samplers);
}

/// Mutable bindings for one [GShader] use.
///
/// Instances own the native FragmentShader and may be shared by multiple
/// renderables when shared uniform state is intentional.
final class GShaderInstance implements _GDisposable {
  GShaderInstance._(this.shader, this._native, Map<String, int> samplers)
    : _samplerIndices = samplers.isEmpty
          ? const <String, int>{}
          : Map<String, int>.unmodifiable(samplers);

  final GShader shader;
  final ui.FragmentShader _native;
  final Map<String, int> _samplerIndices;
  final Map<String, GShaderFloat> _floats = <String, GShaderFloat>{};
  final Map<String, GShaderVec2> _vec2s = <String, GShaderVec2>{};
  final Map<String, GShaderVec3> _vec3s = <String, GShaderVec3>{};
  final Map<String, GShaderVec4> _vec4s = <String, GShaderVec4>{};
  final Map<String, GShaderSampler> _samplers = <String, GShaderSampler>{};
  final Map<int, GShaderSampler> _indexedSamplers = <int, GShaderSampler>{};
  final List<GShaderSampler> _boundSamplers = <GShaderSampler>[];
  final List<VoidCallback> _listeners = <VoidCallback>[];
  bool _disposed = false;

  ui.FragmentShader get _nativeShader {
    _ensureAlive();
    // CanvasKit does not reliably retain sampler bindings across subsequent
    // uniform mutation/draws. Rebinding active samplers at draw time matches
    // Flutter's portable numeric sampler path and costs nothing for shaders
    // without textures.
    for (var i = 0; i < _boundSamplers.length; ++i) {
      _boundSamplers[i]._bind();
    }
    return _native;
  }

  GShaderFloat float(String name) {
    _ensureAlive();
    return _floats[name] ??= GShaderFloat._(
      this,
      _native.getUniformFloat(name),
    );
  }

  GShaderVec2 vec2(String name) {
    _ensureAlive();
    return _vec2s[name] ??= GShaderVec2._(this, _native.getUniformVec2(name));
  }

  GShaderVec3 vec3(String name) {
    _ensureAlive();
    return _vec3s[name] ??= GShaderVec3._(this, _native.getUniformVec3(name));
  }

  GShaderVec4 vec4(String name) {
    _ensureAlive();
    return _vec4s[name] ??= GShaderVec4._(this, _native.getUniformVec4(name));
  }

  /// Returns a stable named sampler binding.
  ///
  /// For portable web use, provide the name->index mapping to
  /// [GShader.instance]. Without an explicit mapping this falls back to
  /// Flutter's named sampler API when that backend supports it.
  GShaderSampler texture(String name) {
    _ensureAlive();
    final existing = _samplers[name];
    if (existing != null) return existing;
    final sampler = switch (_samplerIndices[name]) {
      final int index => GShaderSampler._indexed(this, index),
      null => GShaderSampler._named(this, _native.getImageSampler(name)),
    };
    _samplers[name] = sampler;
    _boundSamplers.add(sampler);
    return sampler;
  }

  /// Low-level sampler binding by sampler declaration order.
  GShaderSampler textureAt(int index) {
    _ensureAlive();
    if (index < 0) throw RangeError.value(index, 'index');
    final existing = _indexedSamplers[index];
    if (existing != null) return existing;
    final sampler = GShaderSampler._indexed(this, index);
    _indexedSamplers[index] = sampler;
    _boundSamplers.add(sampler);
    return sampler;
  }

  GShaderInstance setFloat(String name, double value) {
    float(name).value = value;
    return this;
  }

  GShaderInstance setVec2(String name, double x, double y) {
    vec2(name).set(x, y);
    return this;
  }

  GShaderInstance setVec3(String name, double x, double y, double z) {
    vec3(name).set(x, y, z);
    return this;
  }

  GShaderInstance setVec4(String name, double x, double y, double z, double w) {
    vec4(name).set(x, y, z, w);
    return this;
  }

  GShaderInstance setColor(String name, Color color) {
    final a = color.a;
    vec4(name).set(color.r * a, color.g * a, color.b * a, a);
    return this;
  }

  GShaderInstance setTexture(String name, GTexture texture) {
    this.texture(name).set(texture);
    return this;
  }

  /// Low-level texture mutation by sampler declaration order.
  GShaderInstance setTextureAt(int index, GTexture texture) {
    textureAt(index).set(texture);
    return this;
  }

  GShaderVec2? _tryVec2(String name) {
    try {
      return vec2(name);
    } catch (_) {
      return null;
    }
  }

  void _listen(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void _unlisten(VoidCallback listener) => _listeners.remove(listener);

  void _changed() {
    if (_disposed) return;
    for (var i = 0; i < _listeners.length; ++i) {
      _listeners[i]();
    }
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('GShaderInstance is disposed.');
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _listeners.clear();
    _floats.clear();
    _vec2s.clear();
    _vec3s.clear();
    _vec4s.clear();
    _samplers.clear();
    _indexedSamplers.clear();
    _boundSamplers.clear();
    _native.dispose();
  }
}

/// Stable scalar binding suitable for hot-loop mutation and motion targets.
final class GShaderFloat {
  GShaderFloat._(this._owner, this._slot);

  final GShaderInstance _owner;
  final ui.UniformFloatSlot _slot;
  double _value = 0.0;

  double get value => _value;
  set value(double value) {
    _owner._ensureAlive();
    if (_value == value) return;
    _value = value;
    _slot.set(value);
    _owner._changed();
  }
}

final class GShaderVec2 {
  GShaderVec2._(this._owner, this._slot);

  final GShaderInstance _owner;
  final ui.UniformVec2Slot _slot;
  double _x = double.nan;
  double _y = double.nan;

  void set(double x, double y) {
    _owner._ensureAlive();
    if (_x == x && _y == y) return;
    _x = x;
    _y = y;
    _slot.set(x, y);
    _owner._changed();
  }
}

final class GShaderVec3 {
  GShaderVec3._(this._owner, this._slot);

  final GShaderInstance _owner;
  final ui.UniformVec3Slot _slot;
  double _x = double.nan;
  double _y = double.nan;
  double _z = double.nan;

  void set(double x, double y, double z) {
    _owner._ensureAlive();
    if (_x == x && _y == y && _z == z) return;
    _x = x;
    _y = y;
    _z = z;
    _slot.set(x, y, z);
    _owner._changed();
  }
}

final class GShaderVec4 {
  GShaderVec4._(this._owner, this._slot);

  final GShaderInstance _owner;
  final ui.UniformVec4Slot _slot;
  double _x = double.nan;
  double _y = double.nan;
  double _z = double.nan;
  double _w = double.nan;

  void set(double x, double y, double z, double w) {
    _owner._ensureAlive();
    if (_x == x && _y == y && _z == z && _w == w) return;
    _x = x;
    _y = y;
    _z = z;
    _w = w;
    _slot.set(x, y, z, w);
    _owner._changed();
  }
}

final class GShaderSampler {
  GShaderSampler._named(this._owner, this._slot) : _index = null;
  GShaderSampler._indexed(this._owner, this._index) : _slot = null;

  final GShaderInstance _owner;
  final ui.ImageSamplerSlot? _slot;
  final int? _index;
  GTexture? _texture;

  GTexture? get value => _texture;

  void set(GTexture texture) {
    _owner._ensureAlive();
    if (texture.isDisposed) {
      throw StateError('Cannot bind a disposed GTexture.');
    }
    if (identical(_texture, texture)) return;
    _texture = texture;
    _bind();
    _owner._changed();
  }

  void _bind() {
    final texture = _texture;
    if (texture == null) return;
    if (texture.isDisposed) {
      throw StateError('Cannot bind a disposed GTexture.');
    }
    final slot = _slot;
    if (slot != null) {
      slot.set(texture.image);
    } else {
      _owner._native.setImageSampler(_index!, texture.image);
    }
  }
}

/// Backend-neutral constructors for common retained Canvas shaders.
abstract final class GGradient {
  static GPaintShader linear(
    Offset from,
    Offset to,
    List<Color> colors, [
    List<double>? stops,
    TileMode tileMode = TileMode.clamp,
  ]) => ui.Gradient.linear(from, to, colors, stops, tileMode);

  static GPaintShader radial(
    Offset center,
    double radius,
    List<Color> colors, [
    List<double>? stops,
    TileMode tileMode = TileMode.clamp,
    GMatrix2? matrix,
    Offset? focal,
    double focalRadius = 0.0,
  ]) {
    Float64List? transform;
    if (matrix != null) {
      transform = Float64List(16)
        ..[0] = matrix.a
        ..[1] = matrix.b
        ..[4] = matrix.c
        ..[5] = matrix.d
        ..[10] = 1.0
        ..[12] = matrix.tx
        ..[13] = matrix.ty
        ..[15] = 1.0;
    }
    return ui.Gradient.radial(
      center,
      radius,
      colors,
      stops,
      tileMode,
      transform,
      focal,
      focalRadius,
    );
  }

  static GPaintShader sweep(
    Offset center,
    List<Color> colors, [
    List<double>? stops,
    TileMode tileMode = TileMode.clamp,
    double startAngle = 0.0,
    double endAngle = math.pi * 2.0,
    GMatrix2? matrix,
  ]) {
    Float64List? transform;
    if (matrix != null) {
      transform = Float64List(16)
        ..[0] = matrix.a
        ..[1] = matrix.b
        ..[4] = matrix.c
        ..[5] = matrix.d
        ..[10] = 1.0
        ..[12] = matrix.tx
        ..[13] = matrix.ty
        ..[15] = 1.0;
    }
    return ui.Gradient.sweep(
      center,
      colors,
      stops,
      tileMode,
      startAngle,
      endAngle,
      transform,
    );
  }
}
