// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Flutter's [TextStyle], with a GraphX name to make your life easier, Mr developer.
typedef GTextStyle = TextStyle;

final class GTextRun {
  const GTextRun(this.text, {this.style});
  final String text;
  final GTextStyle? style;
}

/// Retained canvas text node backed directly by a `dart:ui` [ui.Paragraph].
/// Paragraph construction and layout are invalidated independently.
final class GText extends GNode {
  GText(
    String text, {
    GTextStyle style = const GTextStyle(),
    double maxWidth = double.infinity,
    TextAlign align = TextAlign.left,
    TextDirection direction = TextDirection.ltr,
    int? maxLines,
    String? ellipsis,
  }) : _text = text,
       _style = style,
       _maxWidth = _validateMaxWidth(maxWidth),
       _align = align,
       _direction = direction,
       _maxLines = _validateMaxLines(maxLines),
       _ellipsis = ellipsis {
    setPaintSelf(true);
  }

  factory GText.rich(
    List<GTextRun> runs, {
    GTextStyle style = const GTextStyle(),
    double maxWidth = double.infinity,
    TextAlign align = TextAlign.left,
    TextDirection direction = TextDirection.ltr,
    int? maxLines,
    String? ellipsis,
  }) {
    final node = GText(
      '',
      style: style,
      maxWidth: maxWidth,
      align: align,
      direction: direction,
      maxLines: maxLines,
      ellipsis: ellipsis,
    );
    node._runs = List<GTextRun>.unmodifiable(runs);
    return node;
  }

  static const GTextStyle defaultStyle = GTextStyle(
    color: Color(0xff000000),
    fontSize: 14,
  );
  static const double _webMeasureWidth = 10000.0;

  String _text;
  List<GTextRun>? _runs;
  GTextStyle _style;
  GTextStyle? _resolvedStyle;
  bool _resolvedStyleDirty = true;
  double _maxWidth;
  TextAlign _align;
  TextDirection _direction;
  int? _maxLines;
  String? _ellipsis;

  ui.Paragraph? _paragraph;
  bool _paragraphDirty = true;
  bool _layoutDirty = true;
  double _textWidth = 0.0;
  double _textHeight = 0.0;
  double _layoutWidth = 0.0;
  double _layoutHeight = 0.0;
  int _lineCount = -1;

  String get text => _text;
  set text(String value) {
    if (_runs == null && _text == value) return;
    _runs = null;
    _text = value;
    _markParagraphDirty();
  }

  List<GTextRun>? get runs => _runs;
  set runs(List<GTextRun>? value) {
    if (value == null) {
      if (_runs == null) return;
      _runs = null;
    } else {
      _runs = List<GTextRun>.unmodifiable(value);
      _text = '';
    }
    _markParagraphDirty();
  }

  /// Sparse local style. Missing properties are resolved from [GDefaults].
  GTextStyle get style => _style;
  set style(GTextStyle value) {
    if (_style == value) return;
    _style = value;
    _markStyleDirty();
  }

  Color? get color => _ensureResolvedStyle().color;
  set color(Color? value) {
    if (_style.color == value) return;
    _style = _style.copyWith(color: value);
    _markStyleDirty();
  }

  double get maxWidth => _maxWidth;
  set maxWidth(double value) {
    final next = _validateMaxWidth(value);
    if (_maxWidth == next) return;
    _maxWidth = next;
    _markLayoutDirty();
  }

  TextAlign get align => _align;
  set align(TextAlign value) {
    if (_align == value) return;
    _align = value;
    _markParagraphDirty();
  }

  TextDirection get direction => _direction;
  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    _markParagraphDirty();
  }

  int? get maxLines => _maxLines;
  set maxLines(int? value) {
    final next = _validateMaxLines(value);
    if (_maxLines == next) return;
    _maxLines = next;
    _markParagraphDirty();
  }

  String? get ellipsis => _ellipsis;
  set ellipsis(String? value) {
    if (_ellipsis == value) return;
    _ellipsis = value;
    _markParagraphDirty();
  }

  double get textWidth {
    _ensureLayout();
    return _textWidth;
  }

  double get textHeight {
    _ensureLayout();
    return _textHeight;
  }

  double get layoutWidth {
    _ensureLayout();
    return _layoutWidth;
  }

  double get layoutHeight {
    _ensureLayout();
    return _layoutHeight;
  }

  int get lineCount {
    _ensureLayout();
    if (_lineCount >= 0) return _lineCount;
    return _lineCount = _paragraph?.computeLineMetrics().length ?? 0;
  }

  bool get didExceedMaxLines {
    _ensureLayout();
    return _paragraph?.didExceedMaxLines ?? false;
  }

  @override
  void attached() {
    _GTextFontMonitor.attach(this);
    _resolvedStyleDirty = true;
    _paragraphDirty = true;
    _layoutDirty = true;
    invalidateBounds();
  }

  @override
  void detached() => _GTextFontMonitor.detach(this);

  @override
  void computeSelfBounds(GBounds out) {
    _ensureLayout();
    if (_layoutWidth <= 0.0 || _layoutHeight <= 0.0) {
      out.setEmpty();
      return;
    }
    out.setXYWH(0.0, 0.0, _layoutWidth, _layoutHeight);
  }

  @override
  void paintSelf(GRenderContext context) {
    _ensureLayout();
    final paragraph = _paragraph;
    if (paragraph == null) return;
    _stage?._activeStats?.text.paragraphPaints.increment();

    final alpha = context.alpha;
    if (alpha <= 0.0) return;
    if (alpha >= 1.0 && !context.hasColorTransform) {
      context.canvas.drawParagraph(paragraph, ui.Offset.zero);
      return;
    }

    final clipped = context.saveRenderStateLayer(
      ui.Rect.fromLTWH(0.0, 0.0, _layoutWidth, _layoutHeight),
    );
    context.canvas.drawParagraph(paragraph, ui.Offset.zero);
    context.restoreRenderStateLayer(clipped);
  }

  void _fontChanged() => _markParagraphDirty();
  void _defaultsChanged() => _markStyleDirty();
  void _textScalerChanged() => _markParagraphDirty();

  void _markStyleDirty() {
    _resolvedStyleDirty = true;
    // Resolve lazily so inherited changes that do not affect this text can
    // keep its retained paragraph. Bounds stay conservative until resolution.
    invalidateBounds();
    invalidatePaint();
  }

  void _markParagraphDirty() {
    _paragraphDirty = true;
    _layoutDirty = true;
    _lineCount = -1;
    invalidateBounds();
    invalidatePaint();
  }

  void _markLayoutDirty() {
    _layoutDirty = true;
    _lineCount = -1;
    invalidateBounds();
    invalidatePaint();
  }

  GTextStyle _ensureResolvedStyle() {
    if (!_resolvedStyleDirty && isAttached) return _resolvedStyle!;

    final previous = _resolvedStyle;
    final next = _resolveTextStyle(this, _style);
    _resolvedStyle = next;
    // Detached nodes can be freely reparented without lifecycle callbacks, so
    // keep ancestry-derived state lazy until they enter a stage.
    _resolvedStyleDirty = !isAttached;

    if (previous == null) {
      _paragraphDirty = true;
      _layoutDirty = true;
      _lineCount = -1;
      return next;
    }

    switch (previous.compareTo(next)) {
      case RenderComparison.layout:
      case RenderComparison.paint:
        // ui.Paragraph is immutable and must be laid out after rebuilding.
        // A geometry-reuse fast path showed no measurable gain on web.
        _paragraphDirty = true;
        _layoutDirty = true;
        _lineCount = -1;
        break;
      case RenderComparison.metadata:
      case RenderComparison.identical:
        break;
    }
    return next;
  }

  void _ensureLayout() {
    _ensureResolvedStyle();
    if (_paragraphDirty) _buildParagraph();
    if (_layoutDirty) _layoutParagraph();
  }

  void _buildParagraph() {
    if (_isEmpty) {
      _paragraph = null;
      _paragraphDirty = false;
      _layoutDirty = true;
      return;
    }
    _stage?._activeStats?.text.paragraphBuilds.increment();
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: _align,
        textDirection: _direction,
        maxLines: _maxLines,
        ellipsis: _ellipsis,
      ),
    );
    final style = _ensureResolvedStyle();
    final textScaler = _resolveTextScaler(this);
    final runs = _runs;
    if (runs == null) {
      builder.pushStyle(style.getTextStyle(textScaler: textScaler));
      builder.addText(_text);
    } else {
      for (var i = 0; i < runs.length; ++i) {
        final run = runs[i];
        if (run.text.isEmpty) continue;
        final runStyle = run.style == null ? style : style.merge(run.style);
        builder.pushStyle(runStyle.getTextStyle(textScaler: textScaler));
        builder.addText(run.text);
        builder.pop();
      }
    }
    _paragraph = builder.build();
    _paragraphDirty = false;
    _layoutDirty = true;
  }

  void _layoutParagraph() {
    final paragraph = _paragraph;
    _lineCount = -1;
    if (paragraph == null) {
      _textWidth = _textHeight = _layoutWidth = _layoutHeight = 0.0;
      _layoutDirty = false;
      return;
    }
    _stage?._activeStats?.text.paragraphLayouts.increment();
    if (_maxWidth.isFinite) {
      paragraph.layout(ui.ParagraphConstraints(width: _maxWidth));
      _layoutWidth = _maxWidth;
    } else {
      paragraph.layout(
        ui.ParagraphConstraints(
          width: kIsWeb ? _webMeasureWidth : double.maxFinite,
        ),
      );
      final naturalWidth = paragraph.maxIntrinsicWidth;
      paragraph.layout(ui.ParagraphConstraints(width: naturalWidth));
      _layoutWidth = naturalWidth;
    }
    _textWidth = paragraph.longestLine;
    _textHeight = paragraph.height;
    _layoutHeight = paragraph.height;
    _layoutDirty = false;
  }

  bool get _isEmpty {
    final runs = _runs;
    if (runs == null) return _text.isEmpty;
    for (var i = 0; i < runs.length; ++i) {
      if (runs[i].text.isNotEmpty) return false;
    }
    return true;
  }

  static double _validateMaxWidth(double value) {
    if (value == double.infinity) return value;
    if (!value.isFinite || value < 0.0) {
      throw ArgumentError.value(
        value,
        'maxWidth',
        'Must be >= 0 or double.infinity.',
      );
    }
    return value;
  }

  static int? _validateMaxLines(int? value) {
    if (value == null || value > 0) return value;
    throw ArgumentError.value(value, 'maxLines', 'Must be > 0 or null.');
  }
}

final class _GTextFontMonitor {
  static final Set<GText> _texts = <GText>{};
  static bool _listening = false;

  static void attach(GText text) {
    if (!_texts.add(text) || _listening) return;
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    _listening = true;
  }

  static void detach(GText text) {
    if (!_texts.remove(text) || _texts.isNotEmpty || !_listening) return;
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _listening = false;
  }

  static void _fontsChanged() {
    for (final text in _texts) text._fontChanged();
  }
}
