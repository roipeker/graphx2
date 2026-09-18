part of 'package:graphx/src/graphx_impl.dart';

/// Fast visibility mask shared by render views and retained render groups.
///
/// Bits are intentionally just an [int]: matching in the traversal hot path is
/// one bitwise AND. [bit] limits named user bits to 0..30 so behavior is
/// predictable across Dart VM, JavaScript and Wasm targets.
extension type const GRenderMask(int bits) {
  static const GRenderMask none = GRenderMask(0);
  static const GRenderMask all = GRenderMask(-1);

  static GRenderMask bit(int index) {
    if (index < 0 || index > 30) {
      throw RangeError.range(index, 0, 30, 'index');
    }
    return GRenderMask(1 << index);
  }

  GRenderMask operator |(GRenderMask other) => GRenderMask(bits | other.bits);
  GRenderMask operator &(GRenderMask other) => GRenderMask(bits & other.bits);

  bool overlaps(GRenderMask other) => (bits & other.bits) != 0;
  bool get isEmpty => bits == 0;
}

/// One retained view of a Stage world.
///
/// [transform] maps Stage/world coordinates into viewport-local coordinates;
/// [viewport] places and clips that result in Stage output coordinates. A Stage
/// with no registered views keeps the legacy single-pass identity renderer.
///
/// The rectangle and matrix are mutable retained objects. Call [invalidate]
/// after changing either in place. Higher-level packages such as
/// `graphx_camera` own those mutations and keep the view allocation-free while
/// moving every frame.
final class GRenderView {
  GRenderView({
    GRect? viewport,
    GMatrix2? transform,
    GRenderMask mask = GRenderMask.all,
    bool enabled = true,
    bool inputEnabled = true,
  }) : viewport = viewport ?? GRect(),
       transform = transform ?? GMatrix2(),
       _mask = mask,
       _enabled = enabled,
       _inputEnabled = inputEnabled;

  final GRect viewport;
  final GMatrix2 transform;

  GStageRenderViews? _owner;
  GRenderMask _mask;
  bool _enabled;
  bool _inputEnabled;

  GRenderMask get mask => _mask;
  set mask(GRenderMask value) {
    if (_mask.bits == value.bits) return;
    _mask = value;
    invalidate();
  }

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    invalidate();
  }

  /// Whether this view participates in Stage-surface to world input mapping.
  bool get inputEnabled => _inputEnabled;
  set inputEnabled(bool value) {
    if (_inputEnabled == value) return;
    _inputEnabled = value;
    _owner?._stage._nodePointerRouter?._markSceneChanged();
  }

  double get scaleX =>
      math.sqrt(transform.a * transform.a + transform.b * transform.b);
  double get scaleY =>
      math.sqrt(transform.c * transform.c + transform.d * transform.d);
  double get maxScale => math.max(scaleX, scaleY);

  bool containsStagePoint(double x, double y) =>
      enabled && !viewport.isEmpty && viewport.contains(x, y);

  void worldToStageInto(double x, double y, GPoint out) {
    transform.transformPointInto(x, y, out);
    out.x += viewport.x;
    out.y += viewport.y;
  }

  GPoint worldToStage(double x, double y) {
    final out = GPoint();
    worldToStageInto(x, y, out);
    return out;
  }

  bool stageToWorldInto(double x, double y, GPoint out) =>
      transform.inverseTransformPointInto(x - viewport.x, y - viewport.y, out);

  GPoint? stageToWorld(double x, double y) {
    final out = GPoint();
    return stageToWorldInto(x, y, out) ? out : null;
  }

  /// Marks in-place viewport/transform mutations visible to the host.
  void invalidate() {
    final owner = _owner;
    if (owner == null) return;
    owner._stage._nodePointerRouter?._markSceneChanged();
    owner._stage.requestPaint();
  }
}

/// Sparse Stage-owned collection of explicit render views.
///
/// Creating this facade is the opt-in boundary. Ordinary stages allocate no
/// list and continue through the existing identity render path.
final class GStageRenderViews implements _GDisposable {
  GStageRenderViews._(this._stage) {
    _disposeSub = _stage.signals.onDispose.add(dispose, key: this);
  }

  final GStage _stage;
  final List<GRenderView> _items = <GRenderView>[];
  late final GSignalSubscription _disposeSub;
  bool _disposed = false;

  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  GRenderView operator [](int index) => _items[index];
  List<GRenderView> get views => List<GRenderView>.unmodifiable(_items);

  void add(GRenderView view) {
    _checkAlive();
    final owner = view._owner;
    if (identical(owner, this)) {
      if (_items.isNotEmpty && identical(_items.last, view)) return;
      _items.remove(view);
      _items.add(view);
      _changed();
      return;
    }
    if (owner != null) {
      throw StateError('Render view already belongs to another Stage.');
    }
    view._owner = this;
    _items.add(view);
    _changed();
  }

  bool remove(GRenderView view) {
    if (_disposed || !identical(view._owner, this)) return false;
    final removed = _items.remove(view);
    if (!removed) return false;
    view._owner = null;
    _changed();
    return true;
  }

  void bringToFront(GRenderView view) {
    _checkOwned(view);
    if (identical(_items.last, view)) return;
    _items.remove(view);
    _items.add(view);
    _changed();
  }

  void sendToBack(GRenderView view) {
    _checkOwned(view);
    if (identical(_items.first, view)) return;
    _items.remove(view);
    _items.insert(0, view);
    _changed();
  }

  void clear() {
    if (_items.isEmpty) return;
    for (var i = 0; i < _items.length; ++i) {
      _items[i]._owner = null;
    }
    _items.clear();
    if (!_disposed) _changed();
  }

  void _checkOwned(GRenderView view) {
    _checkAlive();
    if (!identical(view._owner, this)) {
      throw ArgumentError('Render view does not belong to this Stage.');
    }
  }

  void _changed() {
    _stage._nodePointerRouter?._markSceneChanged();
    _stage.requestPaint();
  }

  void _checkAlive() {
    if (_disposed || _stage.isDisposed) {
      throw StateError('Stage render views are disposed.');
    }
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (var i = 0; i < _items.length; ++i) {
      _items[i]._owner = null;
    }
    _items.clear();
    _disposeSub.cancel();
  }
}

final Expando<GStageRenderViews> _gRenderViewsByStage =
    Expando<GStageRenderViews>('graphx.renderViews');

GStageRenderViews? _renderViewsOf(GStage stage) {
  final views = _gRenderViewsByStage[stage];
  return views == null || views.isDisposed ? null : views;
}

extension GStageRenderViewsExtension on GStage {
  /// Explicit Stage views, allocated only when first requested.
  GStageRenderViews get renderViews {
    if (isDisposed) throw StateError('Stage is disposed.');
    final existing = _renderViewsOf(this);
    if (existing != null) return existing;
    final value = GStageRenderViews._(this);
    _gRenderViewsByStage[this] = value;
    return value;
  }

  bool get hasRenderViews => _renderViewsOf(this)?.isNotEmpty ?? false;
}

/// Retained subtree whose visibility is selected by [GRenderView.mask].
///
/// The mask applies to the whole subtree, so a rejected group costs one
/// bitwise AND and no descendant traversal. Use nested groups for coarse render
/// layers; ordinary [GNode] instances carry no render-mask storage.
final class GRenderGroup extends GNode {
  GRenderGroup({GRenderMask mask = GRenderMask.all, super.name})
    : _renderMask = mask;

  GRenderMask _renderMask;

  GRenderMask get renderMask => _renderMask;
  set renderMask(GRenderMask value) {
    if (_renderMask.bits == value.bits) return;
    _renderMask = value;
    invalidatePaint();
  }
}

final Expando<GRenderView> _gActiveRenderView = Expando<GRenderView>(
  'graphx.activeRenderView',
);

extension GRenderContextView on GRenderContext {
  /// Explicit view used by the current Stage render pass, or null for the
  /// legacy identity pass and detached subtree captures.
  GRenderView? get renderView => _gActiveRenderView[this];

  GRenderMask get renderMask => renderView?.mask ?? GRenderMask.all;

  /// Largest world-to-view scale in the current pass.
  ///
  /// Pixel-sensitive renderers combine this with node/world scale and
  /// [pixelScale]. Camera/view scale remains separate from retained node
  /// transforms and output backing density.
  double get viewScale => renderView?.maxScale ?? 1.0;
}

extension _GRenderViewRenderer on GCanvasRenderer {
  bool _paintExplicitViews(
    Canvas canvas,
    GStage stage,
    GRenderContext context,
    GRenderStats? stats,
  ) {
    final views = _renderViewsOf(stage)?._items;
    if (views == null || views.isEmpty) return false;

    for (var i = 0; i < views.length; ++i) {
      final view = views[i];
      final viewport = view.viewport;
      if (!view.enabled || viewport.isEmpty || view.mask.isEmpty) continue;

      stats?.canvasSaves.increment();
      canvas.save();
      try {
        canvas.clipRect(
          ui.Rect.fromLTWH(viewport.x, viewport.y, viewport.w, viewport.h),
        );
        canvas.translate(viewport.x, viewport.y);
        _gActiveRenderView[context] = view;
        context
          ..alpha = 1.0
          .._colorDepth = 0
          .._setIdentityColor();
        context.transform(view.transform);
        _paintNode(stage.root, context, 1.0, stats);
      } finally {
        _gActiveRenderView[context] = null;
        context
          ..alpha = 1.0
          .._colorDepth = 0
          .._setIdentityColor();
        canvas.restore();
      }
    }
    return true;
  }

  bool _renderGroupVisible(GRenderGroup group, GRenderContext context) =>
      (group._renderMask.bits & context.renderMask.bits) != 0;
}

GRenderView? _inputRenderViewAt(GStage stage, double x, double y) {
  final views = _renderViewsOf(stage)?._items;
  if (views == null || views.isEmpty) return null;
  for (var i = views.length - 1; i >= 0; --i) {
    final view = views[i];
    if (view.inputEnabled && view.containsStagePoint(x, y)) return view;
  }
  return null;
}
