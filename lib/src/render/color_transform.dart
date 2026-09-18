part of 'package:graphx/graphx.dart';

/// Per-channel render transform inherited by a node's descendants.
///
/// Offsets use the same 0..255 channel units as `ColorFilter.matrix` and
/// Flash's ColorTransform. Identity is allocation-free on [GNode]: nodes only
/// retain transform state after a non-identity value is assigned.
final class GColorTransform {
  const GColorTransform({
    this.redMultiplier = 1.0,
    this.greenMultiplier = 1.0,
    this.blueMultiplier = 1.0,
    this.alphaMultiplier = 1.0,
    this.redOffset = 0.0,
    this.greenOffset = 0.0,
    this.blueOffset = 0.0,
    this.alphaOffset = 0.0,
  });

  static const identity = GColorTransform();

  /// Multiplicative RGB tint. Alpha remains controlled by the node hierarchy.
  factory GColorTransform.tint(Color color) => GColorTransform(
    redMultiplier: color.r,
    greenMultiplier: color.g,
    blueMultiplier: color.b,
  );

  /// Replaces visible RGB with [color] while preserving source alpha.
  factory GColorTransform.color(Color color) => GColorTransform(
    redMultiplier: 0.0,
    greenMultiplier: 0.0,
    blueMultiplier: 0.0,
    redOffset: color.r * 255.0,
    greenOffset: color.g * 255.0,
    blueOffset: color.b * 255.0,
  );

  /// Replaces visible RGB with [color] and multiplies source alpha by its alpha.
  factory GColorTransform.colorize(Color color) => GColorTransform(
    redMultiplier: 0.0,
    greenMultiplier: 0.0,
    blueMultiplier: 0.0,
    alphaMultiplier: color.a,
    redOffset: color.r * 255.0,
    greenOffset: color.g * 255.0,
    blueOffset: color.b * 255.0,
  );

  final double redMultiplier;
  final double greenMultiplier;
  final double blueMultiplier;
  final double alphaMultiplier;
  final double redOffset;
  final double greenOffset;
  final double blueOffset;
  final double alphaOffset;

  bool get isIdentity =>
      redMultiplier == 1.0 &&
      greenMultiplier == 1.0 &&
      blueMultiplier == 1.0 &&
      alphaMultiplier == 1.0 &&
      redOffset == 0.0 &&
      greenOffset == 0.0 &&
      blueOffset == 0.0 &&
      alphaOffset == 0.0;

  /// Returns `parent(local(source))`.
  static GColorTransform combine(
    GColorTransform parent,
    GColorTransform local,
  ) {
    if (parent.isIdentity) return local;
    if (local.isIdentity) return parent;
    return GColorTransform(
      redMultiplier: parent.redMultiplier * local.redMultiplier,
      greenMultiplier: parent.greenMultiplier * local.greenMultiplier,
      blueMultiplier: parent.blueMultiplier * local.blueMultiplier,
      alphaMultiplier: parent.alphaMultiplier * local.alphaMultiplier,
      redOffset: parent.redMultiplier * local.redOffset + parent.redOffset,
      greenOffset:
          parent.greenMultiplier * local.greenOffset + parent.greenOffset,
      blueOffset: parent.blueMultiplier * local.blueOffset + parent.blueOffset,
      alphaOffset:
          parent.alphaMultiplier * local.alphaOffset + parent.alphaOffset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GColorTransform &&
      redMultiplier == other.redMultiplier &&
      greenMultiplier == other.greenMultiplier &&
      blueMultiplier == other.blueMultiplier &&
      alphaMultiplier == other.alphaMultiplier &&
      redOffset == other.redOffset &&
      greenOffset == other.greenOffset &&
      blueOffset == other.blueOffset &&
      alphaOffset == other.alphaOffset;

  @override
  int get hashCode => Object.hash(
    redMultiplier,
    greenMultiplier,
    blueMultiplier,
    alphaMultiplier,
    redOffset,
    greenOffset,
    blueOffset,
    alphaOffset,
  );
}

extension GNodeColorTransform on GNode {
  GColorTransform get colorTransform =>
      _composite?.colorTransform?.value ?? GColorTransform.identity;

  set colorTransform(GColorTransform value) {
    setColorTransformValues(
      value.redMultiplier,
      value.greenMultiplier,
      value.blueMultiplier,
      value.alphaMultiplier,
      value.redOffset,
      value.greenOffset,
      value.blueOffset,
      value.alphaOffset,
    );
    final state = _composite?.colorTransform;
    if (state != null) state._value = value;
  }

  /// Multiplicative RGB tint over this node and its descendants.
  /// Setting null clears the complete color transform.
  Color? get tint => _composite?.colorTransform?.tint;

  set tint(Color? value) {
    if (value == null) {
      colorTransform = GColorTransform.identity;
      return;
    }
    setColorTransformValues(value.r, value.g, value.b, 1.0, 0, 0, 0, 0);
  }

  /// Exact RGB replacement over this node and its descendants.
  ///
  /// Source alpha is preserved and multiplied by the color alpha. Setting null
  /// clears the complete color transform.
  Color? get colorize => _composite?.colorTransform?.colorize;

  set colorize(Color? value) {
    if (value == null) {
      colorTransform = GColorTransform.identity;
      return;
    }
    setColorTransformValues(
      0,
      0,
      0,
      value.a,
      value.r * 255.0,
      value.g * 255.0,
      value.b * 255.0,
      0,
    );
  }

  /// Allocation-free assignment path for imported/animated color transforms.
  void setColorTransformValues(
    double redMultiplier,
    double greenMultiplier,
    double blueMultiplier,
    double alphaMultiplier,
    double redOffset,
    double greenOffset,
    double blueOffset,
    double alphaOffset,
  ) {
    assert(
      redMultiplier.isFinite &&
          greenMultiplier.isFinite &&
          blueMultiplier.isFinite &&
          alphaMultiplier.isFinite &&
          redOffset.isFinite &&
          greenOffset.isFinite &&
          blueOffset.isFinite &&
          alphaOffset.isFinite,
    );

    final identity =
        redMultiplier == 1.0 &&
        greenMultiplier == 1.0 &&
        blueMultiplier == 1.0 &&
        alphaMultiplier == 1.0 &&
        redOffset == 0.0 &&
        greenOffset == 0.0 &&
        blueOffset == 0.0 &&
        alphaOffset == 0.0;
    final composite = _composite;
    if (identity) {
      if (composite?.colorTransform == null) return;
      composite!.colorTransform = null;
      if (composite.isDefault) _composite = null;
      invalidatePaint();
      return;
    }

    final state = _composite ??= _GNodeComposite();
    final color = state.colorTransform ??= _GNodeColorTransform();
    if (color.setValues(
      redMultiplier,
      greenMultiplier,
      blueMultiplier,
      alphaMultiplier,
      redOffset,
      greenOffset,
      blueOffset,
      alphaOffset,
    )) {
      invalidatePaint();
    }
  }
}

final class _GNodeColorTransform {
  double redMultiplier = 1.0;
  double greenMultiplier = 1.0;
  double blueMultiplier = 1.0;
  double alphaMultiplier = 1.0;
  double redOffset = 0.0;
  double greenOffset = 0.0;
  double blueOffset = 0.0;
  double alphaOffset = 0.0;
  GColorTransform? _value;

  GColorTransform get value => _value ??= GColorTransform(
    redMultiplier: redMultiplier,
    greenMultiplier: greenMultiplier,
    blueMultiplier: blueMultiplier,
    alphaMultiplier: alphaMultiplier,
    redOffset: redOffset,
    greenOffset: greenOffset,
    blueOffset: blueOffset,
    alphaOffset: alphaOffset,
  );

  Color? get tint {
    if (alphaMultiplier != 1.0 ||
        redOffset != 0.0 ||
        greenOffset != 0.0 ||
        blueOffset != 0.0 ||
        alphaOffset != 0.0 ||
        redMultiplier < 0.0 ||
        redMultiplier > 1.0 ||
        greenMultiplier < 0.0 ||
        greenMultiplier > 1.0 ||
        blueMultiplier < 0.0 ||
        blueMultiplier > 1.0) {
      return null;
    }
    return Color.fromARGB(
      255,
      (redMultiplier * 255.0).round(),
      (greenMultiplier * 255.0).round(),
      (blueMultiplier * 255.0).round(),
    );
  }

  Color? get colorize {
    if (redMultiplier != 0.0 ||
        greenMultiplier != 0.0 ||
        blueMultiplier != 0.0 ||
        alphaMultiplier < 0.0 ||
        alphaMultiplier > 1.0 ||
        alphaOffset != 0.0 ||
        redOffset < 0.0 ||
        redOffset > 255.0 ||
        greenOffset < 0.0 ||
        greenOffset > 255.0 ||
        blueOffset < 0.0 ||
        blueOffset > 255.0) {
      return null;
    }
    return Color.fromARGB(
      (alphaMultiplier * 255.0).round(),
      redOffset.round(),
      greenOffset.round(),
      blueOffset.round(),
    );
  }

  bool setValues(
    double rm,
    double gm,
    double bm,
    double am,
    double ro,
    double go,
    double bo,
    double ao,
  ) {
    if (redMultiplier == rm &&
        greenMultiplier == gm &&
        blueMultiplier == bm &&
        alphaMultiplier == am &&
        redOffset == ro &&
        greenOffset == go &&
        blueOffset == bo &&
        alphaOffset == ao) {
      return false;
    }
    redMultiplier = rm;
    greenMultiplier = gm;
    blueMultiplier = bm;
    alphaMultiplier = am;
    redOffset = ro;
    greenOffset = go;
    blueOffset = bo;
    alphaOffset = ao;
    _value = null;
    return true;
  }
}
