// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

final class GMath {
  static const e = math.e;
  static const pi = math.pi;
  static const tau = math.pi * 2.0;
  static const halfPi = math.pi * .5;
  static const quarterPi = math.pi * .25;
  static const deg2rad = math.pi / 180.0;
  static const rad2deg = 180.0 / math.pi;

  static const double sqrt2 = 1.4142135623730951;
  static const double invSqrt2 = 0.7071067811865476;
  static const double goldenRatio = 1.618033988749895;

  static const epsilon = 1e-9;

  static final _random = math.Random();

  static double abs(double v) => v.abs();
  static double min(double a, double b) => a < b ? a : b;
  static double max(double a, double b) => a > b ? a : b;
  static double random() => _random.nextDouble();

  static double clamp(double value, [double min = 0.0, double max = 1.0]) {
    assert(min <= max, 'min must be <= max');
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int sign(double value) {
    if (value > 0.0) return 1;
    if (value < 0.0) return -1;
    return 0;
  }

  static double ceil(double a) => a.ceilToDouble();
  static double floor(double a) => a.floorToDouble();
  static double round(double a) => a.roundToDouble();

  static double wrap(double value, double period) {
    assert(period > 0.0, 'period must be > 0');
    return value % period;
  }

  static double sin(double radians) => math.sin(radians);
  static double cos(double radians) => math.cos(radians);
  static double tan(double radians) => math.tan(radians);
  static double asin(double value) => math.asin(value);
  static double acos(double value) => math.acos(value);
  static double atan(double value) => math.atan(value);
  static double atan2(double y, double x) => math.atan2(y, x);
  static double hypo(double x, double y) => math.sqrt(x * x + y * y);

  static double sqrt(double value) => math.sqrt(value);
  static double pow(double base, double exponent) => math.pow(base, exponent).toDouble();
  static double square(double value) => value * value;
  static double cube(double value) => value * value * value;
  static double exp(double value) => math.exp(value);
  static double log(double value) => math.log(value);
  static double log2(double value) => math.log(value) / math.ln2;
  static double log10(double value) => math.log(value) / math.ln10;

  static double radians(double degrees) => degrees * deg2rad;
  static double degrees(double radians) => radians * rad2deg;
  static double wrapAngle(double radians) => wrap(radians, tau);
  static double normalizeAngle(double radians) => wrap(radians + pi, tau) - pi;
  static double deltaAngle(double from, double to) => normalizeAngle(to - from);

  static double lerpAngle(double from, double to, double t) {
    return from + deltaAngle(from, to) * t;
  }

  static double lerp(double a, double b, double t) => a + (b - a) * t;
  static double lerpClamped(double a, double b, double t) => lerp(a, b, clamp(t));

  static double invLerp(double a, double b, double value) {
    final range = b - a;
    if (range == 0.0) return 0.0;
    return (value - a) / range;
  }

  static double lerpCyclic(double a, double b, double t, double period) {
    assert(period > 0.0, 'period must be > 0');
    a = wrap(a, period);
    b = wrap(b, period);
    final delta = b - a;
    if (delta.abs() > period * .5) {
      if (delta > 0.0) {
        a += period;
      } else {
        b += period;
      }
    }
    return wrap(lerp(a, b, t), period);
  }
}

class GRect {
  double x, y, w, h;

  GRect([this.x = 0, this.y = 0, this.w = 0, this.h = 0]);

  void set(double x, double y, double w, double h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }

  void copyFrom(GRect other) {
    x = other.x;
    y = other.y;
    w = other.w;
    h = other.h;
  }

  double get left => x;
  double get top => y;
  double get right => x + w;
  double get bottom => y + h;
  bool get isEmpty => w <= 0 || h <= 0;

  void setEmpty() => x = y = w = h = 0.0;

  bool contains(double px, double py) {
    return px >= x && py >= y && px < x + w && py < y + h;
  }

  bool intersects(GRect other) {
    return !isEmpty &&
        !other.isEmpty &&
        x < other.x + other.w &&
        x + w > other.x &&
        y < other.y + other.h &&
        y + h > other.y;
  }
}

class GSize {
  double width, height;

  GSize(this.width, this.height);
}

class GPoint {
  double x, y;

  GPoint([this.x = 0.0, this.y = 0.0]);

  void set(double x, double y) {
    this.x = x;
    this.y = y;
  }

  void copyFrom(GPoint other) {
    x = other.x;
    y = other.y;
  }

  void setZero() {
    x = 0.0;
    y = 0.0;
  }

  double distanceSquaredTo(GPoint other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return dx * dx + dy * dy;
  }
}

class GMatrix2 {
  double a, b, c, d, tx, ty;

  GMatrix2([
    this.a = 1.0,
    this.b = 0.0,
    this.c = 0.0,
    this.d = 1.0,
    this.tx = 0.0,
    this.ty = 0.0,
  ]);

  bool get isIdentity => a == 1.0 && d == 1.0 && b == 0.0 && c == 0.0 && tx == 0.0 && ty == 0.0;

  void identity() {
    a = d = 1.0;
    b = c = tx = ty = 0.0;
  }

  void setValues(double a, double b, double c, double d, double tx, double ty) {
    this.a = a;
    this.b = b;
    this.c = c;
    this.d = d;
    this.tx = tx;
    this.ty = ty;
  }

  void copyFrom(GMatrix2 other) {
    a = other.a;
    b = other.b;
    c = other.c;
    d = other.d;
    tx = other.tx;
    ty = other.ty;
  }

  void setTransform(
    double x,
    double y,
    double scaleX,
    double scaleY,
    double rotation,
    double skewX,
    double skewY,
    double pivotX,
    double pivotY,
  ) {
    if (skewX == 0.0 && skewY == 0.0) {
      if (rotation == 0.0) {
        a = scaleX;
        b = c = 0.0;
        d = scaleY;
      } else {
        final cos = math.cos(rotation);
        final sin = math.sin(rotation);
        a = cos * scaleX;
        b = sin * scaleX;
        c = -sin * scaleY;
        d = cos * scaleY;
      }
    } else {
      final rotSkewY = rotation + skewY;
      final rotSkewX = rotation - skewX;
      a = math.cos(rotSkewY) * scaleX;
      b = math.sin(rotSkewY) * scaleX;
      c = -math.sin(rotSkewX) * scaleY;
      d = math.cos(rotSkewX) * scaleY;
    }

    if (pivotX == 0.0 && pivotY == 0.0) {
      tx = x;
      ty = y;
    } else {
      tx = x - pivotX * a - pivotY * c;
      ty = y - pivotX * b - pivotY * d;
    }
  }

  void append(GMatrix2 other) {
    setProduct(this, other);
  }

  void setProduct(GMatrix2 left, GMatrix2 right) {
    final la = left.a;
    final lb = left.b;
    final lc = left.c;
    final ld = left.d;
    final ltx = left.tx;
    final lty = left.ty;
    final ra = right.a;
    final rb = right.b;
    final rc = right.c;
    final rd = right.d;
    final rtx = right.tx;
    final rty = right.ty;

    a = la * ra + lc * rb;
    b = lb * ra + ld * rb;
    c = la * rc + lc * rd;
    d = lb * rc + ld * rd;
    tx = la * rtx + lc * rty + ltx;
    ty = lb * rtx + ld * rty + lty;
  }

  bool invertInto(GMatrix2 output) {
    final a0 = a;
    final b0 = b;
    final c0 = c;
    final d0 = d;
    final tx0 = tx;
    final ty0 = ty;
    final det = a0 * d0 - b0 * c0;
    if (det == 0.0 || !det.isFinite) return false;

    final inv = 1.0 / det;
    final oa = d0 * inv;
    final ob = -b0 * inv;
    final oc = -c0 * inv;
    final od = a0 * inv;

    output.setValues(
      oa,
      ob,
      oc,
      od,
      -(oa * tx0 + oc * ty0),
      -(ob * tx0 + od * ty0),
    );
    return true;
  }

  void transformPointInto(double x, double y, GPoint out) {
    out.x = a * x + c * y + tx;
    out.y = b * x + d * y + ty;
  }

  void transformDeltaInto(double x, double y, GPoint out) {
    out.x = a * x + c * y;
    out.y = b * x + d * y;
  }

  bool inverseTransformPointInto(double x, double y, GPoint out) {
    final det = a * d - b * c;
    if (det == 0.0 || !det.isFinite) return false;

    final inv = 1.0 / det;
    final dx = x - tx;
    final dy = y - ty;

    out.x = (d * dx - c * dy) * inv;
    out.y = (a * dy - b * dx) * inv;
    return true;
  }

  bool inverseTransformDeltaInto(double x, double y, GPoint out) {
    final det = a * d - b * c;
    if (det == 0.0 || !det.isFinite) return false;

    final inv = 1.0 / det;
    out.x = (d * x - c * y) * inv;
    out.y = (a * y - b * x) * inv;
    return true;
  }

  void transformBoundsInto(GBounds input, GBounds output) {
    if (input.isEmpty) {
      output.setEmpty();
      return;
    }

    final x1 = input.x1;
    final y1 = input.y1;
    final x2 = input.x2;
    final y2 = input.y2;

    final p0x = a * x1 + c * y1 + tx;
    final p0y = b * x1 + d * y1 + ty;
    final p1x = a * x2 + c * y1 + tx;
    final p1y = b * x2 + d * y1 + ty;
    final p2x = a * x1 + c * y2 + tx;
    final p2y = b * x1 + d * y2 + ty;
    final p3x = a * x2 + c * y2 + tx;
    final p3y = b * x2 + d * y2 + ty;

    output.set(
      math.min(math.min(p0x, p1x), math.min(p2x, p3x)),
      math.min(math.min(p0y, p1y), math.min(p2y, p3y)),
      math.max(math.max(p0x, p1x), math.max(p2x, p3x)),
      math.max(math.max(p0y, p1y), math.max(p2y, p3y)),
    );
  }
}

/// Axis-aligned bounds stored as two extrema.
///
/// Empty bounds use an inverted range so accumulation needs no extra state.
class GBounds {
  double x1, y1, x2, y2;

  GBounds(this.x1, this.y1, this.x2, this.y2);

  GBounds.empty()
    : x1 = double.infinity,
      y1 = double.infinity,
      x2 = double.negativeInfinity,
      y2 = double.negativeInfinity;

  bool get isEmpty => x1 > x2 || y1 > y2;
  double get width => isEmpty ? 0.0 : x2 - x1;
  double get height => isEmpty ? 0.0 : y2 - y1;

  void set(double x1, double y1, double x2, double y2) {
    this.x1 = x1;
    this.y1 = y1;
    this.x2 = x2;
    this.y2 = y2;
  }

  void setXYWH(double x, double y, double width, double height) {
    x1 = x;
    y1 = y;
    x2 = x + width;
    y2 = y + height;
  }

  void setEmpty() {
    x1 = y1 = double.infinity;
    x2 = y2 = double.negativeInfinity;
  }

  void copyFrom(GBounds other) {
    x1 = other.x1;
    y1 = other.y1;
    x2 = other.x2;
    y2 = other.y2;
  }

  void includePoint(double x, double y) {
    if (x < x1) x1 = x;
    if (y < y1) y1 = y;
    if (x > x2) x2 = x;
    if (y > y2) y2 = y;
  }

  void includeBounds(GBounds other) {
    if (other.isEmpty) return;
    if (isEmpty) {
      copyFrom(other);
      return;
    }
    if (other.x1 < x1) x1 = other.x1;
    if (other.y1 < y1) y1 = other.y1;
    if (other.x2 > x2) x2 = other.x2;
    if (other.y2 > y2) y2 = other.y2;
  }

  bool contains(double x, double y) {
    return !isEmpty && x >= x1 && y >= y1 && x < x2 && y < y2;
  }

  bool intersects(GBounds other) {
    return !isEmpty &&
        !other.isEmpty &&
        x1 < other.x2 &&
        x2 > other.x1 &&
        y1 < other.y2 &&
        y2 > other.y1;
  }

  void expand(double amount) {
    if (isEmpty) return;
    x1 -= amount;
    y1 -= amount;
    x2 += amount;
    y2 += amount;
  }

  void writeRect(GRect out) {
    if (isEmpty) {
      out.setEmpty();
    } else {
      out.set(x1, y1, x2 - x1, y2 - y1);
    }
  }
}
