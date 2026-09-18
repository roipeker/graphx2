// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Read-only cached vector components for plugin/tooling integrations.
///
/// Native shader float uniforms start at zero. The original binding keeps NaN
/// internally only to guarantee the first explicit set is forwarded, so these
/// getters expose the effective pre-set value as zero.
extension GShaderVec2Values on GShaderVec2 {
  double get x => _x.isNaN ? 0.0 : _x;
  double get y => _y.isNaN ? 0.0 : _y;
}

extension GShaderVec3Values on GShaderVec3 {
  double get x => _x.isNaN ? 0.0 : _x;
  double get y => _y.isNaN ? 0.0 : _y;
  double get z => _z.isNaN ? 0.0 : _z;
}

extension GShaderVec4Values on GShaderVec4 {
  double get x => _x.isNaN ? 0.0 : _x;
  double get y => _y.isNaN ? 0.0 : _y;
  double get z => _z.isNaN ? 0.0 : _z;
  double get w => _w.isNaN ? 0.0 : _w;
}
