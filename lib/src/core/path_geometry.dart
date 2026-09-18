// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

const double _gDefaultPathSampleStep = 1.0;

void _validatePathSampleStep(double sampleStep) {
  if (!sampleStep.isFinite || sampleStep <= 0.0) {
    throw ArgumentError.value(
      sampleStep,
      'sampleStep',
      'Must be finite and > 0.',
    );
  }
}

/// Samples [path] at approximately [sampleStep] local-space unit intervals.
///
/// [segments] receives x0,y0,x1,y1 tuples when supplied. [bounds] receives the
/// sampled centerline bounds, expanded by [boundsPad], when supplied. The
/// caller owns both outputs.
void _samplePathGeometry(
  Path path,
  double sampleStep, {
  List<double>? segments,
  GBounds? bounds,
  double boundsPad = 0.0,
}) {
  for (final metric in path.computeMetrics()) {
    final length = metric.length;
    if (length <= 0.0) continue;

    final first = metric.getTangentForOffset(0.0)?.position;
    if (first == null) continue;

    var ax = first.dx;
    var ay = first.dy;
    _includeSampleBounds(bounds, ax, ay, boundsPad);

    var distance = sampleStep;
    while (distance < length) {
      final point = metric.getTangentForOffset(distance)?.position;
      if (point != null) {
        if (segments != null) {
          segments
            ..add(ax)
            ..add(ay)
            ..add(point.dx)
            ..add(point.dy);
        }
        ax = point.dx;
        ay = point.dy;
        _includeSampleBounds(bounds, ax, ay, boundsPad);
      }
      distance += sampleStep;
    }

    final last =
        metric.getTangentForOffset(length)?.position ??
        metric.getTangentForOffset(math.max(0.0, length - 1e-6))?.position;
    if (last != null) {
      if (last.dx != ax || last.dy != ay) {
        if (segments != null) {
          segments
            ..add(ax)
            ..add(ay)
            ..add(last.dx)
            ..add(last.dy);
        }
      }
      _includeSampleBounds(bounds, last.dx, last.dy, boundsPad);
    }
  }
}

void _includeSampleBounds(GBounds? bounds, double x, double y, double pad) {
  if (bounds == null) return;
  if (pad == 0.0) {
    bounds.includePoint(x, y);
    return;
  }
  bounds.includePoint(x - pad, y - pad);
  bounds.includePoint(x + pad, y + pad);
}

void _sampledSegmentBounds(Float32List segments, GBounds out) {
  out.setEmpty();
  for (var i = 0; i < segments.length; i += 4) {
    out.includePoint(segments[i], segments[i + 1]);
    out.includePoint(segments[i + 2], segments[i + 3]);
  }
}

double _distanceSquaredToSegments(
  Float32List segments,
  double x,
  double y, [
  GPoint? nearest,
]) {
  var best = double.infinity;
  var nearestX = 0.0;
  var nearestY = 0.0;

  for (var i = 0; i < segments.length; i += 4) {
    final ax = segments[i];
    final ay = segments[i + 1];
    final bx = segments[i + 2];
    final by = segments[i + 3];
    final abx = bx - ax;
    final aby = by - ay;
    final apx = x - ax;
    final apy = y - ay;
    final lenSq = abx * abx + aby * aby;

    var t = lenSq == 0.0 ? 0.0 : (apx * abx + apy * aby) / lenSq;
    if (t < 0.0) {
      t = 0.0;
    } else if (t > 1.0) {
      t = 1.0;
    }

    final px = ax + abx * t;
    final py = ay + aby * t;
    final dx = x - px;
    final dy = y - py;
    final distanceSq = dx * dx + dy * dy;
    if (distanceSq >= best) continue;

    best = distanceSq;
    nearestX = px;
    nearestY = py;
  }

  if (nearest != null && best.isFinite) {
    nearest.set(nearestX, nearestY);
  }
  return best;
}
