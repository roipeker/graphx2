part of 'package:graphx/graphx.dart';

/// Hosts Flutter-backed [GPortal] nodes around the GraphX surface.
///
/// Flutter owns portal widget rendering, gestures, focus and semantics. GraphX
/// owns portal placement, world transform, alpha, visibility and lifecycle.
final class _GPortalHost extends StatefulWidget {
  const _GPortalHost({required this.stage, required this.child});

  final GStage stage;
  final Widget child;

  @override
  State<_GPortalHost> createState() => _GPortalHostState();
}

final class _GPortalEntry {
  _GPortalEntry(this.portal)
    : content = _GPortalCapture(
        portal: portal,
        child: _GPortalContent(portal: portal),
      );

  final GPortal<dynamic> portal;
  final _GPortalVisualState visual = _GPortalVisualState();

  // RenderTransform retains the Matrix4 supplied by its widget configuration.
  // Ping-pong buffers avoid mutating the previous configuration in place.
  final Matrix4 _transformA = Matrix4.identity();
  final Matrix4 _transformB = Matrix4.identity();
  bool _useA = false;

  // Kept by identity so transform-only host rebuilds never rebuild portal
  // content. Only GPortal.child/value/rebuild() touches _GPortalContent.
  final Widget content;

  Matrix4 nextTransform() {
    _useA = !_useA;
    final out = _useA ? _transformA : _transformB;
    out.setFrom(visual.transform);
    return out;
  }
}

final class _GPortalHostState extends State<_GPortalHost> {
  late _GPortalDomain _domain;
  final Map<GPortal<dynamic>, _GPortalEntry> _entries =
      <GPortal<dynamic>, _GPortalEntry>{};

  int? _deferredRebuildId;
  bool _structureDirty = false;

  @override
  void initState() {
    super.initState();
    _attachDomain(widget.stage);
  }

  @override
  void didUpdateWidget(covariant _GPortalHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stage, widget.stage)) {
      _detachDomain();
      _entries.clear();
      _attachDomain(widget.stage);
    }
  }

  void _attachDomain(GStage stage) {
    _domain = _portalDomainFor(stage);
    _domain.addListener(_handleStructureChanged);
    _domain.addVisualListener(_handleVisualChanged);
  }

  void _detachDomain() {
    _domain.removeListener(_handleStructureChanged);
    _domain.removeVisualListener(_handleVisualChanged);
  }

  void _handleStructureChanged() {
    _structureDirty = true;
    _scheduleDeferredRebuild();
  }

  void _handleVisualChanged() {
    if (!mounted) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      setState(() {});
      return;
    }
    _scheduleDeferredRebuild();
  }

  void _scheduleDeferredRebuild() {
    if (!mounted || _deferredRebuildId != null) return;
    _deferredRebuildId = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _deferredRebuildId = null;
      if (!mounted) return;
      _pruneEntriesIfNeeded();
      setState(() {});
    });
  }

  void _pruneEntriesIfNeeded() {
    if (!_structureDirty) return;
    _structureDirty = false;
    final portals = _domain.portals;
    _entries.removeWhere((portal, _) => !portals.contains(portal));
  }

  @override
  Widget build(BuildContext context) {
    _pruneEntriesIfNeeded();
    final portals = _domain.portals;
    return _GStageCapture(
      stage: widget.stage,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (final portal in portals)
            if (portal.placement == GPortalPlacement.behind)
              _buildPortal(portal),
          _GSemanticsHost(stage: widget.stage, child: widget.child),
          for (final portal in portals)
            if (portal.placement == GPortalPlacement.front)
              _buildPortal(portal),
        ],
      ),
    );
  }

  Widget _buildPortal(GPortal<dynamic> portal) {
    final entry = _entries.putIfAbsent(portal, () => _GPortalEntry(portal));
    final visual = entry.visual..resolve(portal);
    final visible = visual.visible && visual.alpha > 0.0;

    return Positioned(
      key: ObjectKey(portal),
      left: 0.0,
      top: 0.0,
      width: portal.width,
      height: portal.height,
      child: Transform(
        alignment: Alignment.topLeft,
        transform: entry.nextTransform(),
        transformHitTests: true,
        child: IgnorePointer(
          ignoring: !portal.pointerEnabled || !visible,
          child: Opacity(
            opacity: visible ? visual.alpha : 0.0,
            child: entry.content,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    final callbackId = _deferredRebuildId;
    _deferredRebuildId = null;
    if (callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callbackId);
    }
    _detachDomain();
    super.dispose();
  }
}

final class _GPortalCapture extends SingleChildRenderObjectWidget {
  const _GPortalCapture({required this.portal, required super.child});

  final GPortal<dynamic> portal;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderGPortalCapture(portal);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderGPortalCapture renderObject,
  ) {
    renderObject.portal = portal;
  }
}

/// Tiny proxy used to report layout size and capture portal pixels.
/// It is a repaint boundary only when requested or while snapshotting.
final class _RenderGPortalCapture extends RenderProxyBox {
  _RenderGPortalCapture(GPortal<dynamic> portal) : _portal = portal {
    portal._link.capture = this;
  }

  GPortal<dynamic> _portal;
  int _captures = 0;

  GPortal<dynamic> get portal => _portal;

  set portal(GPortal<dynamic> value) {
    if (identical(_portal, value)) return;
    if (identical(_portal._link.capture, this)) _portal._link.capture = null;
    _portal = value;
    value._link.capture = this;
    markNeedsLayout();
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => portal.repaintBoundary || _captures != 0;

  @override
  void performLayout() {
    super.performLayout();
    portal._setLayoutSize(size.width, size.height);
  }

  Future<GTexture> capture(GRect area, double scale) async {
    _captures++;
    if (_captures == 1 && !portal.repaintBoundary) {
      markNeedsCompositingBitsUpdate();
      markNeedsPaint();
    }

    try {
      // Wait for the promoted boundary to contain the latest Flutter paint.
      await SchedulerBinding.instance.endOfFrame;
      if (!attached) throw StateError('GPortal detached during snapshot().');

      final captureLayer = _snapshotLayer('snapshot()');
      final image = await captureLayer.toImage(
        ui.Rect.fromLTWH(area.x, area.y, area.w, area.h),
        pixelRatio: scale,
      );
      return GTexture.owned(image, scale: scale);
    } finally {
      _captures--;
      if (_captures == 0 && !portal.repaintBoundary && attached) {
        markNeedsCompositingBitsUpdate();
        markNeedsPaint();
      }
    }
  }

  GTexture captureSync(GRect area, double scale) {
    if (!portal.repaintBoundary) {
      throw StateError(
        'GPortal.snapshotSync() requires repaintBoundary: true because it '
        'cannot promote and paint a capture boundary synchronously. '
        'Set repaintBoundary: true or use await portal.snapshot().',
      );
    }

    assert(() {
      if (debugNeedsPaint || debugNeedsLayout) {
        throw StateError(
          'GPortal.snapshotSync() was called before pending layout/paint '
          'completed. Wait until after the frame, or use await portal.snapshot().',
        );
      }
      return true;
    }());

    final captureLayer = _snapshotLayer('snapshotSync()');
    final image = captureLayer.toImageSync(
      ui.Rect.fromLTWH(area.x, area.y, area.w, area.h),
      pixelRatio: scale,
    );
    return GTexture.owned(image, scale: scale);
  }

  OffsetLayer _snapshotLayer(String api) {
    final captureLayer = layer;
    if (captureLayer is! OffsetLayer) {
      throw StateError(
        'GPortal.$api requires an already-painted composited portal. '
        'Use await portal.snapshot() to wait for a valid capture boundary.',
      );
    }
    if (!captureLayer.supportsRasterization()) {
      throw StateError(
        'GPortal.$api cannot rasterize this Flutter subtree. '
        'Platform views and other non-rasterizable layers cannot be snapshotted.',
      );
    }
    return captureLayer;
  }

  @override
  void dispose() {
    if (identical(_portal._link.capture, this)) _portal._link.capture = null;
    super.dispose();
  }
}

/// Stable boundary around the user-owned Flutter subtree.
///
/// Portal transform/alpha changes never rebuild this widget. Only explicit
/// portal content mutations (`child`, `value`, or `rebuild`) do.
final class _GPortalContent extends StatefulWidget {
  const _GPortalContent({required this.portal});

  final GPortal<dynamic> portal;

  @override
  State<_GPortalContent> createState() => _GPortalContentState();
}

final class _GPortalContentState extends State<_GPortalContent> {
  GPortal<dynamic> get portal => widget.portal;

  @override
  void initState() {
    super.initState();
    portal._link.contentState = this;
  }

  void rebuildContent() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => portal._buildPortalChild(context);

  @override
  void dispose() {
    if (identical(portal._link.contentState, this)) {
      portal._link.contentState = null;
    }
    super.dispose();
  }
}
