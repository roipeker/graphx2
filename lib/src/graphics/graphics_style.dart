// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Gradient families supported by [GGraphics.beginGradientFill].
enum GGradientType { linear, radial, sweep }

sealed class _GGraphicsBrush {
  const _GGraphicsBrush();

  bool get isAntiAlias;
  BlendMode get blendMode;
}

final class _GSolidGraphicsBrush extends _GGraphicsBrush {
  const _GSolidGraphicsBrush(
    this.color, {
    this.isAntiAlias = true,
    this.blendMode = BlendMode.srcOver,
  });

  final Color color;
  @override
  final bool isAntiAlias;
  @override
  final BlendMode blendMode;
}

final class _GGradientGraphicsBrush extends _GGraphicsBrush {
  _GGradientGraphicsBrush(
    this.type,
    List<Color> colors, {
    List<double>? ratios,
    this.begin = Alignment.center,
    this.end = Alignment.centerRight,
    this.rotation = 0.0,
    this.tileMode = TileMode.clamp,
    this.gradientBox,
    this.radius = 0.5,
    this.focalRadius = 0.0,
    this.sweepStartAngle = 0.0,
    this.sweepEndAngle = math.pi * 2.0,
    this.isAntiAlias = true,
    this.blendMode = BlendMode.srcOver,
  }) : colors = List<Color>.unmodifiable(colors),
       ratios = ratios == null ? null : List<double>.unmodifiable(ratios) {
    if (colors.length < 2) {
      throw ArgumentError.value(
        colors,
        'colors',
        'At least two colors required.',
      );
    }
    if (ratios != null && ratios.length != colors.length) {
      throw ArgumentError('ratios length must match colors length.');
    }
  }

  final GGradientType type;
  final List<Color> colors;
  final List<double>? ratios;
  final Alignment begin;
  final Alignment end;
  final double rotation;
  final TileMode tileMode;
  final Rect? gradientBox;
  final double radius;
  final double focalRadius;
  final double sweepStartAngle;
  final double sweepEndAngle;
  @override
  final bool isAntiAlias;
  @override
  final BlendMode blendMode;
}

final class _GProgramShaderGraphicsBrush extends _GGraphicsBrush {
  _GProgramShaderGraphicsBrush(
    this.shader, {
    this.isAntiAlias = true,
    this.blendMode = BlendMode.srcOver,
    this.filterQuality = FilterQuality.low,
  }) : size = shader._tryVec2('graphx_size');

  final GShaderInstance shader;
  final GShaderVec2? size;
  @override
  final bool isAntiAlias;
  @override
  final BlendMode blendMode;
  final FilterQuality filterQuality;
}

final class _GPaintShaderGraphicsBrush extends _GGraphicsBrush {
  const _GPaintShaderGraphicsBrush(
    this.shader, {
    this.isAntiAlias = true,
    this.blendMode = BlendMode.srcOver,
    this.filterQuality = FilterQuality.low,
  });

  final ui.Shader shader;
  @override
  final bool isAntiAlias;
  @override
  final BlendMode blendMode;
  final FilterQuality filterQuality;
}

final class _GBitmapGraphicsBrush extends _GGraphicsBrush {
  const _GBitmapGraphicsBrush(
    this.texture,
    this.shader, {
    required this.repeat,
    required this.smooth,
    this.blendMode = BlendMode.srcOver,
  });

  final GTexture texture;
  final ui.ImageShader shader;
  final bool repeat;
  final bool smooth;
  @override
  bool get isAntiAlias => smooth;
  @override
  final BlendMode blendMode;

  FilterQuality get filterQuality => smooth ? FilterQuality.medium : FilterQuality.none;
}

final class _GGraphicsStroke {
  const _GGraphicsStroke({
    required this.brush,
    required this.width,
    required this.cap,
    required this.join,
    required this.miterLimit,
    this.geometry,
  });

  final _GGraphicsBrush brush;
  final double width;
  final StrokeCap cap;
  final StrokeJoin join;
  final double miterLimit;
  final _GLineGeometry? geometry;

  _GGraphicsStroke copyWith({
    _GGraphicsBrush? brush,
    _GLineGeometry? geometry,
    bool clearGeometry = false,
  }) => _GGraphicsStroke(
    brush: brush ?? this.brush,
    width: width,
    cap: cap,
    join: join,
    miterLimit: miterLimit,
    geometry: clearGeometry ? null : geometry ?? this.geometry,
  );

  double get boundsPad {
    final half = width * 0.5;
    return join == StrokeJoin.miter ? half * math.max(1.0, miterLimit) : half;
  }
}
