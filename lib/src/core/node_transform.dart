part of 'package:graphx/graphx.dart';

mixin GNodeTransform {
  double _x = 0.0;
  double _y = 0.0;
  double _pivotX = 0.0;
  double _pivotY = 0.0;
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  double _rotation = 0.0;
  double _skewX = 0.0;
  double _skewY = 0.0;

  GMatrix2? _localMatrix;
  GMatrix2? _worldMatrix;

  int _localTransformVersion = 0;
  bool _localMatrixDirty = false;
  bool _localTransformIdentity = true;

  set x(double value) {
    assert(value.isFinite);
    if (_x == value) return;
    _x = value;
    _invalidateTransform();
  }

  double get x => _x;

  set y(double value) {
    assert(value.isFinite);
    if (_y == value) return;
    _y = value;
    _invalidateTransform();
  }

  double get y => _y;

  void setPosition(double x, double y) {
    assert(x.isFinite);
    assert(y.isFinite);
    if (_x == x && _y == y) return;
    _x = x;
    _y = y;
    _invalidateTransform();
  }

  set pivotY(double value) {
    assert(value.isFinite);
    if (_pivotY == value) return;
    _pivotY = value;
    _invalidateTransform();
  }

  double get pivotY => _pivotY;

  set pivotX(double value) {
    assert(value.isFinite);
    if (_pivotX == value) return;
    _pivotX = value;
    _invalidateTransform();
  }

  double get pivotX => _pivotX;

  void setPivot(double x, double y, {bool preserve = false}) {
    assert(x.isFinite);
    assert(y.isFinite);
    if (_pivotX == x && _pivotY == y) return;

    if (preserve) {
      // Resolve once before changing scalar registration. A null matrix here
      // means the effective transform is identity, so no storage is needed.
      if (_localMatrixDirty) _updateLocalMatrix();
      final dx = x - _pivotX;
      final dy = y - _pivotY;
      final matrix = _localMatrix;
      if (matrix == null) {
        _x += dx;
        _y += dy;
      } else {
        _x += matrix.a * dx + matrix.c * dy;
        _y += matrix.b * dx + matrix.d * dy;
      }
      _pivotX = x;
      _pivotY = y;
      return;
    }

    _pivotX = x;
    _pivotY = y;
    _invalidateTransform();
  }

  set scaleY(double value) {
    assert(value.isFinite);
    if (_scaleY == value) return;
    _scaleY = value;
    _invalidateTransform();
  }

  double get scaleY => _scaleY;

  set scaleX(double value) {
    assert(value.isFinite);
    if (_scaleX == value) return;
    _scaleX = value;
    _invalidateTransform();
  }

  double get scaleX => _scaleX;

  /// Uniform-scale shorthand. The getter reflects [scaleX].
  double get scale => _scaleX;
  set scale(double value) => setScale(value);

  void setScale(double x, [double? y]) {
    final sy = y ?? x;
    assert(x.isFinite);
    assert(sy.isFinite);
    if (_scaleX == x && _scaleY == sy) return;
    _scaleX = x;
    _scaleY = sy;
    _invalidateTransform();
  }

  set rotation(double value) {
    assert(value.isFinite);
    if (_rotation == value) return;
    _rotation = value;
    _invalidateTransform();
  }

  double get rotation => _rotation;

  set skewX(double value) {
    assert(value.isFinite);
    if (_skewX == value) return;
    _skewX = value;
    _invalidateTransform();
  }

  double get skewX => _skewX;

  set skewY(double value) {
    assert(value.isFinite);
    if (_skewY == value) return;
    _skewY = value;
    _invalidateTransform();
  }

  double get skewY => _skewY;

  void setSkew(double x, double y) {
    assert(x.isFinite);
    assert(y.isFinite);
    if (_skewX == x && _skewY == y) return;
    _skewX = x;
    _skewY = y;
    _invalidateTransform();
  }

  /// Local affine transform for this node.
  ///
  /// The returned matrix is node-owned and must be treated as read-only.
  /// Identity nodes do not retain matrix storage until this getter is queried.
  GMatrix2 get localMatrix {
    if (_localMatrixDirty) _updateLocalMatrix();
    return _localMatrix ?? _materializeLocalMatrix();
  }

  /// Copies an affine matrix into this node.
  ///
  /// Assignment canonicalizes scalar transform fields using zero pivot and
  /// rotation, with the two affine basis vectors represented by scale/skew.
  /// This preserves the matrix exactly while making later scalar mutations
  /// deterministic. The source matrix is never retained.
  set localMatrix(GMatrix2 value) {
    setLocalMatrixValues(
      value.a,
      value.b,
      value.c,
      value.d,
      value.tx,
      value.ty,
    );
  }

  /// Assigns a local affine transform without requiring a temporary GMatrix2.
  /// Useful for SWF, skeletal animation and other imported matrix streams.
  void setLocalMatrixValues(
    double a,
    double b,
    double c,
    double d,
    double tx,
    double ty,
  ) {
    assert(a.isFinite);
    assert(b.isFinite);
    assert(c.isFinite);
    assert(d.isFinite);
    assert(tx.isFinite);
    assert(ty.isFinite);

    final identity =
        a == 1.0 && b == 0.0 && c == 0.0 && d == 1.0 && tx == 0.0 && ty == 0.0;
    if (!_localMatrixDirty) {
      if (_localTransformIdentity && identity) return;
      final matrix = _localMatrix;
      if (!identity &&
          matrix != null &&
          matrix.a == a &&
          matrix.b == b &&
          matrix.c == c &&
          matrix.d == d &&
          matrix.tx == tx &&
          matrix.ty == ty) {
        return;
      }
    }

    if (identity) {
      _localMatrix?.identity();
    } else {
      _ensureLocalMatrixStorage().setValues(a, b, c, d, tx, ty);
    }
    _localMatrixDirty = false;
    _localTransformIdentity = identity;

    // Any affine 2x2 basis can be represented exactly by the existing
    // rotation/skew model. Canonicalizing to rotation=0 avoids choosing an
    // arbitrary decomposition and keeps subsequent scalar edits predictable.
    _x = tx;
    _y = ty;
    _pivotX = 0.0;
    _pivotY = 0.0;
    _rotation = 0.0;

    final sx = math.sqrt(a * a + b * b);
    final sy = math.sqrt(c * c + d * d);
    _scaleX = sx;
    _scaleY = sy;
    _skewY = sx == 0.0 ? 0.0 : math.atan2(b, a);
    _skewX = sy == 0.0 ? 0.0 : math.atan2(c, d);

    _localTransformVersion++;
    _onLocalMatrixAssigned();
    _onTransformChanged();
  }

  /// Copies the current local matrix into caller-owned storage without forcing
  /// retained matrix storage for identity nodes.
  void copyLocalMatrixInto(GMatrix2 out) {
    if (_localMatrixDirty) _updateLocalMatrix();
    final matrix = _localMatrix;
    if (matrix == null) {
      out.identity();
    } else {
      out.copyFrom(matrix);
    }
  }

  bool get hasLocalTransform {
    if (_localMatrixDirty) _updateLocalMatrix();
    return !_localTransformIdentity;
  }

  GMatrix2 _ensureLocalMatrixStorage() {
    final matrix = _localMatrix;
    if (matrix != null) return matrix;
    return _materializeLocalMatrix();
  }

  GMatrix2 _materializeLocalMatrix() {
    final matrix = GMatrix2();
    _localMatrix = matrix;
    _onLocalMatrixMaterialized();
    return matrix;
  }

  void _updateLocalMatrix() {
    _localMatrixDirty = false;
    final scalarIdentity =
        _x == 0.0 &&
        _y == 0.0 &&
        _scaleX == 1.0 &&
        _scaleY == 1.0 &&
        _rotation == 0.0 &&
        _skewX == 0.0 &&
        _skewY == 0.0 &&
        _pivotX == 0.0 &&
        _pivotY == 0.0;

    if (scalarIdentity) {
      _localTransformIdentity = true;
      _localMatrix?.identity();
    } else {
      final matrix = _ensureLocalMatrixStorage();
      matrix.setTransform(
        _x,
        _y,
        _scaleX,
        _scaleY,
        _rotation,
        _skewX,
        _skewY,
        _pivotX,
        _pivotY,
      );
      _localTransformIdentity = matrix.isIdentity;
    }
    _onLocalMatrixUpdated();
  }

  void _invalidateTransform() {
    // Scalar animation commonly updates several fields in one cascade. Once
    // the matrix is dirty, later writes are already represented by the same
    // pending recompute and do not need to repeat bounds/cache/semantics work.
    if (_localMatrixDirty) return;
    _localMatrixDirty = true;
    _localTransformVersion++;
    _onTransformChanged();
  }

  void _onTransformChanged() {}

  void _onLocalMatrixUpdated() {}

  void _onLocalMatrixAssigned() {}

  void _onLocalMatrixMaterialized() {}
}

extension GNodePivotAlignment on GNode {
  /// Aligns the pivot against this node's current local subtree bounds.
  ///
  /// Alignment uses -1 for left/top, 0 for center, and 1 for right/bottom.
  /// Values outside that range are allowed. Empty bounds leave the pivot
  /// unchanged. By default the complete local transform is preserved.
  void alignPivot(double x, double y, {bool preserve = true}) {
    assert(x.isFinite);
    assert(y.isFinite);

    final bounds = _ensureLocalBounds();
    if (bounds.isEmpty) return;

    setPivot(
      bounds.x1 + bounds.width * ((x + 1.0) * 0.5),
      bounds.y1 + bounds.height * ((y + 1.0) * 0.5),
      preserve: preserve,
    );
  }
}
