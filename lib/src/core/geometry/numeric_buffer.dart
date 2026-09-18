// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Private retained Float32 storage used by high-count core primitives.
/// Growth is explicit; callers own geometric growth policy.
final class _GFloat32Buffer {
  _GFloat32Buffer._(this._data, this._length);

  factory _GFloat32Buffer.growable({int capacity = 0, int length = 0}) {
    if (capacity < 0) {
      throw RangeError.range(capacity, 0, null, 'capacity');
    }
    if (length < 0 || length > capacity) {
      throw RangeError.range(length, 0, capacity, 'length');
    }
    return _GFloat32Buffer._(Float32List(capacity), length);
  }

  Float32List _data;
  int _length;

  Float32List get data => _data;
  int get length => _length;
  int get capacity => _data.length;

  void reserve(int newCapacity) {
    if (newCapacity < 0) {
      throw RangeError.range(newCapacity, 0, null, 'newCapacity');
    }
    if (newCapacity <= capacity) return;
    final next = Float32List(newCapacity);
    next.setRange(0, _length, _data);
    _data = next;
  }

  void setLength(int newLength) {
    if (newLength < 0 || newLength > capacity) {
      throw RangeError.range(newLength, 0, capacity, 'newLength');
    }
    _length = newLength;
  }
}
