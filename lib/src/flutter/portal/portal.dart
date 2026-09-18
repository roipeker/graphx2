// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

typedef GPortalBuilder<T> = Widget Function(BuildContext context, T value);

enum GPortalPlacement { behind, front }

final class GPortal<T> extends GNode {
  GPortal({
    required Widget child,
    double? width,
    double? height,
    bool pointerEnabled = true,
    bool repaintBoundary = true,
    GPortalPlacement placement = GPortalPlacement.front,
  }) : _child = child,
       _builder = null,
       _value = null,
       _hasValue = false,
       _width = _validateExtent(width, 'width'),
       _height = _validateExtent(height, 'height'),
       _pointerEnabled = pointerEnabled,
       repaintBoundary = repaintBoundary,
       _placement = placement;

  GPortal.builder({
    required T value,
    required GPortalBuilder<T> builder,
    double? width,
    double? height,
    bool pointerEnabled = true,
    bool repaintBoundary = true,
    GPortalPlacement placement = GPortalPlacement.front,
  }) : _child = null,
       _builder = builder,
       _value = value,
       _hasValue = true,
       _width = _validateExtent(width, 'width'),
       _height = _validateExtent(height, 'height'),
       _pointerEnabled = pointerEnabled,
       repaintBoundary = repaintBoundary,
       _placement = placement;

  Widget? _child;
  final GPortalBuilder<T>? _builder;
  T? _value;
  final bool _hasValue;

  double? _width;
  double? _height;
  bool _pointerEnabled;
  GPortalPlacement _placement;

  double? get width => _width;
  set width(double? value) {
    value = _validateExtent(value, 'width');
    if (_width == value) return;
    _width = value;
    _domain?.markVisualDirty();
  }

  double? get height => _height;
  set height(double? value) {
    value = _validateExtent(value, 'height');
    if (_height == value) return;
    _height = value;
    _domain?.markVisualDirty();
  }

  GSize get layoutSize => _layoutSize;

  GSignal0 get onLayoutSizeChanged => (_onLayoutSizeChanged ??= GSignal0());

  bool get pointerEnabled => _pointerEnabled;
  set pointerEnabled(bool value) {
    if (_pointerEnabled == value) return;
    _pointerEnabled = value;
    _domain?.markVisualDirty();
  }

  GPortalPlacement get placement => _placement;
  set placement(GPortalPlacement value) {
    if (_placement == value) return;
    _placement = value;
    _domain?.portalPlacementChanged(this);
  }

  final bool repaintBoundary;

  Future<GTexture> snapshot({GRect? area, double scale = 1.0}) {
    final capture = _snapshotCapture();
    return capture.capture(_resolveSnapshotArea(area), _validateScale(scale));
  }

  GTexture snapshotSync({GRect? area, double scale = 1.0}) {
    final capture = _snapshotCapture();
    return capture.captureSync(
      _resolveSnapshotArea(area),
      _validateScale(scale),
    );
  }

  final GSize _layoutSize = GSize(0.0, 0.0);
  final GRect _bounds = GRect();
  final _GPortalLink _link = _GPortalLink();
  GSignal0? _onLayoutSizeChanged;
  bool _layoutSizeSignalPending = false;

  _GPortalDomain? _domain;

  Widget get child {
    if (_builder != null) {
      throw StateError('Builder portals do not expose a static child.');
    }
    return _child!;
  }

  set child(Widget value) {
    if (_builder != null) {
      throw StateError('Builder portals do not expose a static child.');
    }
    if (identical(_child, value)) return;
    _child = value;
    _link.rebuildContent();
  }

  T get value {
    if (!_hasValue) {
      throw StateError('This portal was not created with GPortal.builder().');
    }
    return _value as T;
  }

  set value(T value) {
    if (!_hasValue) {
      throw StateError('This portal was not created with GPortal.builder().');
    }
    if (identical(_value, value)) return;
    _value = value;
    _link.rebuildContent();
  }

  void rebuild() => _link.rebuildContent();

  @override
  U addChild<U extends GNode>(U child) {
    throw UnsupportedError(
      'GPortal is a leaf node. Add GraphX children to its parent instead.',
    );
  }

  Widget _buildPortalChild(BuildContext context) {
    final Widget content;
    final builder = _builder;
    if (builder != null) {
      content = builder(context, _value as T);
    } else {
      content = _child!;
    }
    return _GPortalFocusHost(portal: this, child: content);
  }

  void _setLayoutSize(double width, double height) {
    if (_layoutSize.width == width && _layoutSize.height == height) return;

    _layoutSize.width = width;
    _layoutSize.height = height;
    _bounds.set(0.0, 0.0, width, height);
    invalidateBounds();

    final signal = _onLayoutSizeChanged;
    if (signal == null || _layoutSizeSignalPending) return;

    _layoutSizeSignalPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _layoutSizeSignalPending = false;
      if (_domain == null) return;
      _onLayoutSizeChanged?.emit();
    });
  }

  _RenderGPortalCapture _snapshotCapture() {
    if (layoutSize.width <= 0.0 || layoutSize.height <= 0.0) {
      throw StateError('GPortal must complete layout before snapshotting.');
    }
    final capture = _link.capture;
    if (capture == null || !capture.attached) {
      throw StateError('GPortal must be attached before snapshotting.');
    }
    return capture;
  }

  double _validateScale(double scale) {
    if (!scale.isFinite || scale <= 0.0) {
      throw ArgumentError.value(scale, 'scale', 'Must be finite and > 0.');
    }
    return scale;
  }

  GRect _resolveSnapshotArea(GRect? area) {
    if (area == null) {
      return GRect(0.0, 0.0, layoutSize.width, layoutSize.height);
    }
    if (!area.x.isFinite ||
        !area.y.isFinite ||
        !area.w.isFinite ||
        !area.h.isFinite ||
        area.w <= 0.0 ||
        area.h <= 0.0) {
      throw ArgumentError.value(area, 'area', 'Must be finite and non-empty.');
    }

    final left = math.max(0.0, area.x);
    final top = math.max(0.0, area.y);
    final right = math.min(layoutSize.width, area.x + area.w);
    final bottom = math.min(layoutSize.height, area.y + area.h);
    if (right <= left || bottom <= top) {
      throw ArgumentError.value(area, 'area', 'Does not intersect the portal.');
    }
    return GRect(left, top, right - left, bottom - top);
  }

  @override
  void computeSelfBounds(GBounds out) {
    if (_layoutSize.width <= 0.0 || _layoutSize.height <= 0.0) {
      out.setEmpty();
    } else {
      out.setXYWH(0.0, 0.0, _layoutSize.width, _layoutSize.height);
    }
  }

  @override
  bool hitTestLocal(double x, double y) => _bounds.contains(x, y);

  @override
  void attached() {
    final domain = _portalDomainFor(stage);
    _domain = domain;
    domain.attach(this);
  }

  @override
  void detached() {
    _domain?.detach(this);
    _domain = null;
  }

  static double? _validateExtent(double? value, String name) {
    if (value != null && (!value.isFinite || value < 0.0)) {
      throw ArgumentError.value(
        value,
        name,
        'Must be null or finite and >= 0.',
      );
    }
    return value;
  }
}

final class _GPortalLink {
  _GPortalContentState? contentState;
  _RenderGPortalCapture? capture;
  _GPortalFocusHostState? focusHost;

  void rebuildContent() => contentState?.rebuildContent();
}
