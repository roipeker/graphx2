part of 'package:graphx/graphx.dart';

/// Retained single-glyph font icon node.
///
/// [GIcon] keeps a deterministic square GraphX layout box. Glyph/style
/// changes stay paint-only; changing [size] also invalidates bounds.
final class GIcon extends GNode {
  GIcon(
    IconData data, {
    double? size,
    Color? color,
    ui.Paint? foreground,
    List<Shadow>? shadows,
    TextDirection direction = TextDirection.ltr,
  }) : this._(
         data: data,
         codePoint: data.codePoint,
         fontFamily: data.fontFamily,
         fontPackage: data.fontPackage,
         fontFamilyFallback: data.fontFamilyFallback,
         matchTextDirection: data.matchTextDirection,
         size: size,
         color: color,
         foreground: foreground,
         shadows: shadows,
         direction: direction,
       );

  factory GIcon.glyph(
    int codePoint, {
    String? fontFamily,
    String? fontPackage,
    List<String>? fontFamilyFallback,
    bool matchTextDirection = false,
    double? size,
    Color? color,
    ui.Paint? foreground,
    List<Shadow>? shadows,
    TextDirection direction = TextDirection.ltr,
  }) => GIcon._(
    codePoint: _validateCodePoint(codePoint),
    fontFamily: fontFamily,
    fontPackage: fontPackage,
    fontFamilyFallback: fontFamilyFallback,
    matchTextDirection: matchTextDirection,
    size: size,
    color: color,
    foreground: foreground,
    shadows: shadows,
    direction: direction,
  );

  GIcon._({
    IconData? data,
    required int codePoint,
    required String? fontFamily,
    required String? fontPackage,
    required List<String>? fontFamilyFallback,
    required bool matchTextDirection,
    required double? size,
    required Color? color,
    required ui.Paint? foreground,
    required List<Shadow>? shadows,
    required TextDirection direction,
  }) : _data = data,
       _codePoint = _validateCodePoint(codePoint),
       _fontFamily = fontFamily,
       _fontPackage = fontPackage,
       _fontFamilyFallback = _copyFallback(fontFamilyFallback),
       _matchTextDirection = matchTextDirection,
       _size = size == null ? null : _validateSize(size),
       _color = color,
       _foreground = foreground,
       _shadows = _copyShadows(shadows),
       _direction = direction {
    if (color != null && foreground != null) {
      throw ArgumentError('GIcon color and foreground are mutually exclusive.');
    }
    setPaintSelf(true);
  }

  static const GIconStyle defaultStyle = GIconStyle(
    size: 24.0,
    color: Color(0xff000000),
  );

  IconData? _data;
  int _codePoint;
  String? _fontFamily;
  String? _fontPackage;
  List<String>? _fontFamilyFallback;
  bool _matchTextDirection;
  double? _size;
  Color? _color;
  ui.Paint? _foreground;
  List<Shadow>? _shadows;
  TextDirection _direction;

  GIconStyle? _resolvedStyle;
  bool _resolvedStyleDirty = true;
  TextPainter? _painter;
  bool _painterDirty = true;

  IconData? get data => _data;
  set data(IconData value) {
    final fallback = value.fontFamilyFallback;
    if (_data == value &&
        _codePoint == value.codePoint &&
        _fontFamily == value.fontFamily &&
        _fontPackage == value.fontPackage &&
        listEquals(_fontFamilyFallback, fallback) &&
        _matchTextDirection == value.matchTextDirection) {
      return;
    }
    _data = value;
    _codePoint = value.codePoint;
    _fontFamily = value.fontFamily;
    _fontPackage = value.fontPackage;
    _fontFamilyFallback = _copyFallback(fallback);
    _matchTextDirection = value.matchTextDirection;
    _markPainterDirty();
  }

  int get codePoint => _codePoint;
  set codePoint(int value) {
    final next = _validateCodePoint(value);
    if (_codePoint == next) return;
    _data = null;
    _codePoint = next;
    _markPainterDirty();
  }

  String? get fontFamily => _fontFamily;
  set fontFamily(String? value) {
    if (_fontFamily == value) return;
    _data = null;
    _fontFamily = value;
    _markPainterDirty();
  }

  String? get fontPackage => _fontPackage;
  set fontPackage(String? value) {
    if (_fontPackage == value) return;
    _data = null;
    _fontPackage = value;
    _markPainterDirty();
  }

  List<String>? get fontFamilyFallback => _fontFamilyFallback;
  set fontFamilyFallback(List<String>? value) {
    if (listEquals(_fontFamilyFallback, value)) return;
    _data = null;
    _fontFamilyFallback = _copyFallback(value);
    _markPainterDirty();
  }

  bool get matchTextDirection => _matchTextDirection;
  set matchTextDirection(bool value) {
    if (_matchTextDirection == value) return;
    _data = null;
    _matchTextDirection = value;
    invalidatePaint();
  }

  /// Effective size. Assign `null` to inherit from [GDefaults] again.
  double get size => _ensureResolvedStyle().size!;
  set size(double? value) {
    final next = value == null ? null : _validateSize(value);
    if (_size == next) return;
    _size = next;
    _markStyleDirty(bounds: true);
  }

  /// Effective solid color. Assigning a non-null value clears [foreground].
  /// Assign `null` to inherit the solid color from [GDefaults] again.
  Color get color => _ensureResolvedStyle().color!;
  set color(Color? value) {
    if (_color == value && (value == null || _foreground == null)) return;
    _color = value;
    if (value != null) _foreground = null;
    _markStyleDirty();
  }

  /// Optional native text foreground paint for gradients, shaders, or strokes.
  /// A non-null paint takes precedence over the resolved solid [color].
  ui.Paint? get foreground => _foreground;
  set foreground(ui.Paint? value) {
    if (identical(_foreground, value)) return;
    _foreground = value;
    if (value != null) {
      _color = null;
      _markStyleDirty();
    } else {
      _markPainterDirty();
    }
  }

  /// Native glyph shadows rendered by Flutter's text backend.
  List<Shadow>? get shadows => _shadows;
  set shadows(List<Shadow>? value) {
    if (listEquals(_shadows, value)) return;
    _shadows = _copyShadows(value);
    _markPainterDirty();
  }

  TextDirection get direction => _direction;
  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    _markPainterDirty();
  }

  @override
  void attached() {
    _GIconFontMonitor.attach(this);
    _resolvedStyleDirty = true;
    _painterDirty = true;
  }

  @override
  void detached() => _GIconFontMonitor.detach(this);

  @override
  void dispose() {
    if (isDisposed) return;
    _painter?.dispose();
    _painter = null;
    super.dispose();
  }

  @override
  void computeSelfBounds(GBounds out) {
    final size = _ensureResolvedStyle().size!;
    if (size <= 0.0) {
      out.setEmpty();
      return;
    }
    out.setXYWH(0.0, 0.0, size, size);
  }

  @override
  void paintSelf(GRenderContext context) {
    _ensurePainter();
    final painter = _painter;
    if (painter == null) return;
    _stage?._activeStats?.text.paragraphPaints.increment();

    final alpha = context.alpha;
    if (alpha <= 0.0) return;
    final size = _resolvedStyle!.size!;
    if (alpha >= 1.0 && !context.hasColorTransform) {
      _paint(context.canvas, painter, size);
      return;
    }

    final clipped = context.saveRenderStateLayer(
      ui.Rect.fromLTWH(0.0, 0.0, size, size),
    );
    _paint(context.canvas, painter, size);
    context.restoreRenderStateLayer(clipped);
  }

  void _paint(ui.Canvas canvas, TextPainter painter, double size) {
    final offset = ui.Offset(0.0, (size - painter.height) * .5);
    if (!_matchTextDirection || _direction != TextDirection.rtl) {
      painter.paint(canvas, offset);
      return;
    }

    canvas.save();
    canvas.translate(size, 0.0);
    canvas.scale(-1.0, 1.0);
    painter.paint(canvas, offset);
    canvas.restore();
  }

  void _fontChanged() => _markPainterDirty();
  void _defaultsChanged() => _markStyleDirty(bounds: true);

  void _markStyleDirty({bool bounds = false}) {
    _resolvedStyleDirty = true;
    _markPainterDirty(bounds: bounds);
  }

  void _markPainterDirty({bool bounds = false}) {
    _painterDirty = true;
    if (bounds) invalidateBounds();
    invalidatePaint();
  }

  GIconStyle _ensureResolvedStyle() {
    if (!_resolvedStyleDirty && isAttached) return _resolvedStyle!;

    final previous = _resolvedStyle;
    final next = _resolveIconStyle(this, size: _size, color: _color);
    final size = next.size;
    if (size == null || next.color == null) {
      throw StateError('GIcon defaults must resolve size and color.');
    }
    _validateSize(size);

    _resolvedStyle = next;
    // Detached nodes can be freely reparented without lifecycle callbacks, so
    // keep ancestry-derived state lazy until they enter a stage.
    _resolvedStyleDirty = !isAttached;

    if (previous != null && previous != next) {
      _painterDirty = true;
      if (previous.size != next.size) invalidateBounds();
    }
    return next;
  }

  void _ensurePainter() {
    final style = _ensureResolvedStyle();
    if (!_painterDirty) return;
    final size = style.size!;
    if (size <= 0.0) {
      _painter?.text = null;
      _painterDirty = false;
      return;
    }

    _stage?._activeStats?.text.paragraphBuilds.increment();
    final painter = _painter ??= TextPainter(
      textAlign: TextAlign.center,
      textDirection: _direction,
      maxLines: 1,
    );
    painter
      ..textDirection = _direction
      ..text = TextSpan(
        text: String.fromCharCode(_codePoint),
        style: TextStyle(
          inherit: false,
          color: _foreground == null ? style.color : null,
          foreground: _foreground,
          shadows: _shadows,
          fontSize: size,
          fontFamily: _fontFamily,
          package: _fontPackage,
          fontFamilyFallback: _fontFamilyFallback,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
    _stage?._activeStats?.text.paragraphLayouts.increment();
    painter.layout(minWidth: size, maxWidth: size);
    _painterDirty = false;
  }

  static int _validateCodePoint(int value) {
    if (value >= 0 && value <= 0x10ffff) return value;
    throw ArgumentError.value(
      value,
      'codePoint',
      'Must be a Unicode code point.',
    );
  }

  static double _validateSize(double value) {
    if (value.isFinite && value >= 0.0) return value;
    throw ArgumentError.value(value, 'size', 'Must be a finite value >= 0.');
  }

  static List<String>? _copyFallback(List<String>? value) =>
      value == null ? null : List<String>.unmodifiable(value);

  static List<Shadow>? _copyShadows(List<Shadow>? value) =>
      value == null ? null : List<Shadow>.unmodifiable(value);
}

final class _GIconFontMonitor {
  static final Set<GIcon> _icons = <GIcon>{};
  static bool _listening = false;

  static void attach(GIcon icon) {
    if (!_icons.add(icon) || _listening) return;
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    _listening = true;
  }

  static void detach(GIcon icon) {
    if (!_icons.remove(icon) || _icons.isNotEmpty || !_listening) return;
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _listening = false;
  }

  static void _fontsChanged() {
    for (final icon in _icons) icon._fontChanged();
  }
}
