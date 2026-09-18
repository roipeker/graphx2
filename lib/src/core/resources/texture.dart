// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Common renderable image-data contract used by texture loaders and display
/// objects. Concrete implementations remain intentionally small.
sealed class GTextureData implements _GDisposable {
  double get width;
  double get height;
  bool get isAnimated;
}

/// One rectangular view into a backing image.
///
/// [region] is expressed in backing-image pixels. [sourceWidth]/[sourceHeight]
/// preserve the untrimmed backing-pixel size used by atlas frames.
final class GTextureFrame {
  const GTextureFrame({
    required this.region,
    required this.sourceWidth,
    required this.sourceHeight,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.rotated = false,
  });

  factory GTextureFrame.full(ui.Image image) => GTextureFrame(
    region: GRect(0.0, 0.0, image.width.toDouble(), image.height.toDouble()),
    sourceWidth: image.width.toDouble(),
    sourceHeight: image.height.toDouble(),
  );

  final GRect region;
  final double sourceWidth;
  final double sourceHeight;
  final double offsetX;
  final double offsetY;
  final bool rotated;
}

/// Renderable image data or a view into shared image data.
///
/// [scale] is backing-image pixels per logical GraphX unit. It defaults to
/// 1.0 and is useful for multi-resolution assets and generated captures.
/// Atlas frame geometry remains expressed in backing-image pixels.
final class GTexture implements GTextureData {
  GTexture(
    this.image, {
    GTextureFrame? frame,
    this.scale = 1.0,
    this.ownsImage = false,
  }) : assert(scale > 0.0 && scale.isFinite),
       frame = frame ?? GTextureFrame.full(image);

  factory GTexture.owned(
    ui.Image image, {
    GTextureFrame? frame,
    double scale = 1.0,
  }) => GTexture(image, frame: frame, scale: scale, ownsImage: true);

  final ui.Image image;
  final GTextureFrame frame;
  final double scale;
  final bool ownsImage;

  @override
  double get width => frame.sourceWidth / scale;

  @override
  double get height => frame.sourceHeight / scale;

  @override
  bool get isAnimated => false;

  GTexture region({
    required GRect region,
    double? sourceWidth,
    double? sourceHeight,
    double offsetX = 0.0,
    double offsetY = 0.0,
    bool rotated = false,
  }) {
    _ensureAlive();
    return GTexture(
      image,
      scale: scale,
      frame: GTextureFrame(
        region: region,
        sourceWidth: sourceWidth ?? region.w,
        sourceHeight: sourceHeight ?? region.h,
        offsetX: offsetX,
        offsetY: offsetY,
        rotated: rotated,
      ),
    );
  }

  bool _disposed = false;

  void _ensureAlive() {
    if (_disposed) throw StateError('GTexture is disposed.');
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (ownsImage) image.dispose();
  }
}

/// One timed texture frame in a texture sequence.
final class GTextureSequenceFrame {
  const GTextureSequenceFrame(this.texture, this.duration);

  final GTexture texture;
  final Duration duration;
}

/// Timed renderable texture data.
///
/// This is format-agnostic: decoded GIF/WebP frames, spritesheet animations,
/// atlas sequences, and manually-authored texture clips can all use it.
/// Playback policy belongs to the consuming display object.
final class GTextureSequence implements GTextureData {
  factory GTextureSequence(
    List<GTextureSequenceFrame> frames, {
    bool ownsTextures = false,
  }) {
    if (frames.isEmpty) {
      throw ArgumentError.value(frames, 'frames', 'must not be empty');
    }
    return GTextureSequence._(frames, ownsTextures);
  }

  GTextureSequence._(List<GTextureSequenceFrame> frames, this.ownsTextures)
    : frames = List<GTextureSequenceFrame>.unmodifiable(frames),
      duration = _sumDuration(frames);

  factory GTextureSequence.owned(List<GTextureSequenceFrame> frames) =>
      GTextureSequence(frames, ownsTextures: true);

  final List<GTextureSequenceFrame> frames;
  final bool ownsTextures;
  final Duration duration;

  int get frameCount => frames.length;

  @override
  bool get isAnimated => frameCount > 1;

  GTexture get firstTexture => frames.first.texture;

  @override
  double get width => firstTexture.width;

  @override
  double get height => firstTexture.height;

  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!ownsTextures) return;
    for (final frame in frames) {
      frame.texture.dispose();
    }
  }

  static Duration _sumDuration(List<GTextureSequenceFrame> frames) {
    var micros = 0;
    for (final frame in frames) {
      micros += frame.duration.inMicroseconds;
    }
    return Duration(microseconds: micros);
  }
}
