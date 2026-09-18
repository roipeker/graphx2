part of 'package:graphx/src/graphx_impl.dart';

// for assert dimension issues.
const kGxDebugWarnIfZeroSize = true;

typedef GraphXRootFactory = GRoot Function();

class GraphXView extends StatefulWidget {
  const GraphXView({
    super.key,
    required this.root,
    this.controller,
    this.value,
    this.config = GraphXConfig.defaults,
  });

  GraphXView.scene(
    GraphXSceneBuilder build, {
    super.key,
    this.controller,
    this.value,
    this.config = GraphXConfig.sceneDefaults,
  }) : root = (() => GCallbackRoot(build));

  final GraphXRootFactory root;
  final GraphXController? controller;
  final GraphXConfig config;
  final Object? value;

  @override
  State<GraphXView> createState() => _GraphXViewState();
}

class _GraphXViewState extends State<GraphXView> {
  late GRoot _root;
  late GStage _stage;
  GraphXController? _controller;
  GRuntime? _sharedRuntime;
  bool _initialized = false;
  bool _pendingRestart = false;

  bool _flutterSyncPending = true;
  bool _dependenciesChanged = true;

  void _installScene(GRuntime? sharedRuntime) {
    final scene = _createScene(sharedRuntime);
    try {
      widget.controller?._attachRoot(scene.root);
    } catch (_) {
      scene.stage.dispose();
      rethrow;
    }
    _root = scene.root;
    _stage = scene.stage;
    _controller = widget.controller;
    _initialized = true;
    _markFlutterSync(dependenciesChanged: true);
  }

  ({GRoot root, GStage stage}) _createScene(GRuntime? sharedRuntime) {
    final root = widget.root();
    final stage = GStage(
      root,
      maxDelta: widget.config.maxDelta,
      inputEnabled: widget.config.inputEnabled,
      runtime: sharedRuntime,
    );
    try {
      stage.mount();
    } catch (_) {
      stage.dispose();
      rethrow;
    }
    return (root: root, stage: stage);
  }

  void _replaceScene() {
    final prev = (root: _root, stage: _stage, ctr: _controller);
    final next = _createScene(_sharedRuntime);
    try {
      prev.ctr?._detachRoot(prev.root);
      try {
        prev.ctr?._attachRoot(next.root);
      } catch (_) {
        prev.ctr?._attachRoot(prev.root);
        rethrow;
      }
    } catch (_) {
      next.stage.dispose();
      rethrow;
    }
    _root = next.root;
    _stage = next.stage;
    prev.stage.dispose();
  }

  void _markFlutterSync({bool dependenciesChanged = false}) {
    _flutterSyncPending = true;
    _dependenciesChanged |= dependenciesChanged;
  }

  void _flushFlutterSync() {
    if (!_flutterSyncPending || _stage.isDisposed) return;
    final dependenciesChanged = _dependenciesChanged;
    _flutterSyncPending = false;
    _dependenciesChanged = false;
    _stage._syncFlutter(
      context,
      widget.value,
      dependenciesChanged: dependenciesChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sharedRuntime = GRuntimeProvider.maybeOf(context);
    if (!_initialized) {
      _sharedRuntime = sharedRuntime;
      _installScene(sharedRuntime);
    } else if (!identical(_sharedRuntime, sharedRuntime)) {
      _sharedRuntime = sharedRuntime;
      _stage._setRuntime(sharedRuntime);
    }
    _stage._setFlutterContext(context);
    _stage._syncEnvironment(context);
    _markFlutterSync(dependenciesChanged: true);
  }

  @override
  void didUpdateWidget(covariant GraphXView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldConfig = oldWidget.config;
    final config = widget.config;

    if (oldConfig.maxDelta != config.maxDelta) {
      _stage.maxDelta = config.maxDelta;
    }

    if (oldConfig.inputEnabled != config.inputEnabled) {
      _stage.input.enabled = config.inputEnabled;
    }

    if (!identical(oldWidget.controller, widget.controller)) {
      final prev = _controller;
      final next = widget.controller;
      next?._attachRoot(_root);
      prev?._detachRoot(_root);
      _controller = next;
    }

    _markFlutterSync();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (!_initialized) return;
    switch (widget.config.reloadMode) {
      case GraphXReloadMode.retain:
        _stage.reassemble();
        _markFlutterSync(dependenciesChanged: true);
      case GraphXReloadMode.restart:
        _pendingRestart = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(_initialized);
    if (_pendingRestart) {
      _pendingRestart = false;
      _replaceScene();
      _markFlutterSync(dependenciesChanged: true);
    }
    final surface = LayoutBuilder(
      builder: (context, constraints) {
        final size = RenderGraphXSurface._computeSize(constraints);
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        _stage._setFlutterContext(context);
        _stage.setViewport(
          size.width,
          size.height,
          devicePixelRatio: devicePixelRatio,
        );
        _stage._syncEnvironment(context);
        if (_stage._rootAttached) _flushFlutterSync();
        return _GPortalHost(
          stage: _stage,
          child: _GraphXSurface(
            stage: _stage,
            repaintBoundary: widget.config.repaintBoundary,
            pointerEnabled: widget.config.pointer,
            hitTestBehavior: widget.config.hitTestBehavior,
            devicePixelRatio: devicePixelRatio,
          ),
        );
      },
    );
    return _GFocusHost(
      stage: _stage,
      captureRawKeyboard: widget.config.keyboard,
      autofocus: widget.config.autofocus,
      child: surface,
    );
  }

  @override
  void dispose() {
    if (_initialized) {
      _controller?._detachRoot(_root);
      _controller = null;
      _stage.dispose();
    }
    super.dispose();
  }
}

final class _GraphXSurface extends LeafRenderObjectWidget {
  const _GraphXSurface({
    required this.stage,
    required this.repaintBoundary,
    required this.devicePixelRatio,
    required this.pointerEnabled,
    required this.hitTestBehavior,
  });

  final GStage stage;
  final bool repaintBoundary;
  final double devicePixelRatio;
  final bool pointerEnabled;
  final GHitTestBehavior hitTestBehavior;

  @override
  RenderGraphXSurface createRenderObject(BuildContext context) {
    return RenderGraphXSurface(
      stage,
      repaintBoundary,
      devicePixelRatio,
      pointerEnabled,
      hitTestBehavior,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderGraphXSurface renderObject,
  ) {
    renderObject
      ..stage = stage
      ..pointerEnabled = pointerEnabled
      ..hitTestBehavior = hitTestBehavior
      ..repaintBoundary = repaintBoundary
      ..devicePixelRatio = devicePixelRatio;
  }
}

final class RenderGraphXSurface extends RenderBox
    implements GStageHost, MouseTrackerAnnotation {
  RenderGraphXSurface(
    GStage stage,
    this.repaintBoundary, [
    double devicePixelRatio = 1.0,
    this.pointerEnabled = true,
    this.hitTestBehavior = GHitTestBehavior.opaque,
  ]) : _stage = stage,
       _devicePixelRatio = devicePixelRatio;

  bool repaintBoundary;
  bool pointerEnabled;
  GHitTestBehavior hitTestBehavior;
  double _devicePixelRatio;

  double get devicePixelRatio => _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsLayout();
  }

  GStage _stage;

  GStage get stage => _stage;

  set stage(GStage value) {
    if (identical(value, _stage)) return;
    final old = _stage;
    final callbackId = _frameCallbackId;
    _frameCallbackId = null;
    if (callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callbackId);
    }
    if (attached) old.detachHost(this);
    _stage = value;
    if (attached) value.attachHost(this);
    markNeedsLayout();
    markNeedsPaint();
  }

  final _renderer = GCanvasRenderer();
  int? _frameCallbackId;
  BoxConstraints? _lastWarnedConstraints;

  @override
  bool hitTestSelf(Offset position) {
    if (!pointerEnabled || !stage.input.enabled || stage.isDisposed) {
      return false;
    }
    return switch (hitTestBehavior) {
      GHitTestBehavior.opaque => true,
      GHitTestBehavior.content =>
        _resolveInteractiveHit(stage, position.dx, position.dy) != null,
    };
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (!pointerEnabled || !stage.input.enabled || stage.isDisposed) return;
    switch (event) {
      case PointerScrollEvent():
        _handlePointerScroll(event);
      case PointerPanZoomStartEvent():
        _handlePanZoomStart(event);
      case PointerPanZoomUpdateEvent():
        _handlePanZoomUpdate(event);
      case PointerPanZoomEndEvent():
        _handlePanZoomEnd(event);
      case PointerDownEvent():
        _dispatchPointer(event, GPointerEventType.down);
      case PointerMoveEvent():
        _dispatchPointer(event, GPointerEventType.move);
      case PointerUpEvent():
        _dispatchPointer(event, GPointerEventType.up);
      case PointerCancelEvent():
        _dispatchPointer(event, GPointerEventType.cancel);
      case PointerHoverEvent():
        _dispatchPointer(event, GPointerEventType.hover);
      default:
        break;
    }
  }

  void _dispatchPointer(PointerEvent event, GPointerEventType type) {
    final local = globalToLocal(event.position);
    final previousButtons = stage.input.pointer.buttons;
    final button = switch (type) {
      GPointerEventType.down => event.buttons & ~previousButtons,
      GPointerEventType.up => previousButtons & ~event.buttons,
      _ => 0,
    };
    stage.input.pointer._dispatch(
      GPointerEvent(
        type: type,
        pointer: event.pointer,
        kind: _convertPointerKind(event.kind),
        x: local.dx,
        y: local.dy,
        deltaX: event.localDelta.dx,
        deltaY: event.localDelta.dy,
        button: button,
        buttons: event.buttons,
        timestamp: event.timeStamp,
      ),
    );
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (resolved is! PointerScrollEvent) return;
      if (!pointerEnabled || !stage.input.enabled || stage.isDisposed) return;
      final local = globalToLocal(resolved.position);
      stage.input.pointer._dispatchScroll(
        GPointerEvent(
          type: GPointerEventType.scroll,
          pointer: resolved.pointer,
          kind: _convertPointerKind(resolved.kind),
          x: local.dx,
          y: local.dy,
          deltaX: 0.0,
          deltaY: 0.0,
          scrollX: resolved.scrollDelta.dx,
          scrollY: resolved.scrollDelta.dy,
          scrollSource: GPointerScrollSource.wheel,
          buttons: resolved.buttons,
          timestamp: resolved.timeStamp,
        ),
      );
    });
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    final local = globalToLocal(event.position);
    stage.input.pointer._beginPanZoom(
      pointer: event.pointer,
      x: local.dx,
      y: local.dy,
    );
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final local = globalToLocal(event.position);
    stage.input.pointer._updatePanZoom(
      pointer: event.pointer,
      x: local.dx,
      y: local.dy,
      panX: event.localPan.dx,
      panY: event.localPan.dy,
      panDeltaX: event.localPanDelta.dx,
      panDeltaY: event.localPanDelta.dy,
      scale: event.scale,
      rotation: event.rotation,
      timestamp: event.timeStamp,
    );
  }

  void _handlePanZoomEnd(PointerPanZoomEndEvent event) {
    stage.input.pointer._endPanZoom();
  }

  static GPointerDeviceKind _convertPointerKind(PointerDeviceKind kind) {
    return switch (kind) {
      PointerDeviceKind.mouse => GPointerDeviceKind.mouse,
      PointerDeviceKind.touch => GPointerDeviceKind.touch,
      PointerDeviceKind.stylus => GPointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus => GPointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad => GPointerDeviceKind.trackpad,
      PointerDeviceKind.unknown => GPointerDeviceKind.unknown,
    };
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    stage.attachHost(this);
  }

  @override
  void detach() {
    final callbackId = _frameCallbackId;
    _frameCallbackId = null;
    if (callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callbackId);
    }
    stage.detachHost(this);
    super.detach();
  }

  @override
  void scheduleTick() {
    if (!attached || _frameCallbackId != null) return;
    final scheduledStage = _stage;
    _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback((
      timestamp,
    ) {
      _frameCallbackId = null;
      if (!attached ||
          !identical(_stage, scheduledStage) ||
          scheduledStage.isDisposed) {
        return;
      }
      scheduledStage.handleFrame(timestamp);
    });
  }

  @override
  void schedulePaint() {
    if (!attached) return;
    _maybePortalDomainFor(stage)?.markVisualDirty();
    markNeedsPaint();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeSize(constraints);

  @override
  void performLayout() {
    size = _computeSize(constraints);
    assert(() {
      _debugCheckSize();
      return true;
    }());
    stage.setViewport(
      size.width,
      size.height,
      devicePixelRatio: devicePixelRatio,
    );
  }

  static Size _computeSize(BoxConstraints constraints) {
    final w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.minWidth;
    final h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.minHeight;
    return constraints.constrain(Size(w, h));
  }

  void _debugCheckSize() {
    if (!kGxDebugWarnIfZeroSize) return;
    final hasUsableSize = !size.isEmpty;
    if (hasUsableSize) {
      _lastWarnedConstraints = null;
      return;
    }
    if (_lastWarnedConstraints == constraints) return;
    _lastWarnedConstraints = constraints;
    final warning = FlutterError.fromParts([
      ErrorSummary('GraphXView was laid out with a zero-sized viewport.'),
      ErrorDescription(
        'The resulting GraphX viewport is ${size.width.toStringAsFixed(1)} x ${size.height.toStringAsFixed(1)}.',
      ),
      DiagnosticsProperty('Received constraints', constraints),
      if (!constraints.hasBoundedWidth)
        ErrorHint(
          'The width is unbounded. Give GraphXView an explicit width, '
          'place it in Expanded, or ensure its parent constraints the '
          'horizontal axis.',
        ),
      if (!constraints.hasBoundedHeight)
        ErrorHint(
          'The height is unbounded. Give GraphXView an explicit height, '
          'place it in Expanded, or ensure its parent constraints the '
          'vertical axis.',
        ),
      if (constraints.hasTightWidth && constraints.maxWidth == 0.0)
        ErrorHint(
          'The parent forced the width to zero. Inspect the surrounding '
          'SizedBox, Flex, animation, or custom layout.',
        ),
      if (constraints.hasTightHeight && constraints.maxHeight == 0.0)
        ErrorHint(
          'The parent forced the height to zero. Inspect the surrounding '
          'SizedBox, Flex, animation, or custom layout.',
        ),
      if (constraints.hasBoundedWidth &&
          constraints.maxWidth > 0.0 &&
          size.width == 0)
        ErrorHint(
          'A non-zero width was available, but the chosen width was zero.'
          'Usually indicates incorrect RenderGraphXSurface sizing.',
        ),
      if (constraints.hasBoundedHeight &&
          constraints.maxHeight > 0.0 &&
          size.height == 0)
        ErrorHint(
          'A non-zero height was available, but the chosen height was zero.'
          'Usually indicates incorrect RenderGraphXSurface sizing.',
        ),
      ErrorHint(
        'Common fixes:\n'
        ' Expanded( child: GraphXView(...))\n'
        ' SizedBox( width: ..., height: ..., child: GraphXView(...))\n'
        ' AspectRatio( aspectRatio: ..., child: GraphXView(...))',
      ),
      if (debugCreator != null)
        DiagnosticsProperty(
          'The relevant GraphXView was created by',
          debugCreator!,
          style: DiagnosticsTreeStyle.errorProperty,
        ),
    ]);
    debugPrint(warning.toString());
  }

  @override
  bool get isRepaintBoundary => repaintBoundary;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (stage.isDisposed || !stage.isMounted) return;
    stage.consumePaintRequest();
    final canvas = context.canvas;
    if (offset == Offset.zero) {
      _renderer.render(canvas, stage);
      if (!kReleaseMode) _gInspectorRuntime.paintOverlay(canvas, stage);
      return;
    }
    canvas.save();
    try {
      canvas.translate(offset.dx, offset.dy);
      _renderer.render(canvas, stage);
      if (!kReleaseMode) _gInspectorRuntime.paintOverlay(canvas, stage);
    } finally {
      canvas.restore();
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  MouseCursor _mouseCursor = MouseCursor.defer;

  @override
  MouseCursor get cursor => _mouseCursor;

  @override
  PointerEnterEventListener? get onEnter {
    return pointerEnabled && stage.input.enabled ? _handleEnter : null;
  }

  @override
  PointerExitEventListener? get onExit {
    return pointerEnabled && stage.input.enabled ? _handleExit : null;
  }

  void _handleEnter(PointerEnterEvent event) {
    if (!pointerEnabled || !stage.input.enabled || stage.isDisposed) return;
    final local = globalToLocal(event.position);
    stage.input.pointer._dispatchEnter(
      GPointerBoundaryEvent(
        type: GPointerBoundaryEventType.enter,
        kind: _convertPointerKind(event.kind),
        pointer: event.pointer,
        x: local.dx,
        y: local.dy,
        timestamp: event.timeStamp,
      ),
    );
  }

  void _handleExit(PointerExitEvent event) {
    if (!pointerEnabled || !stage.input.enabled || stage.isDisposed) return;
    final local = globalToLocal(event.position);
    stage.input.pointer._dispatchExit(
      GPointerBoundaryEvent(
        type: GPointerBoundaryEventType.exit,
        pointer: event.pointer,
        kind: _convertPointerKind(event.kind),
        x: local.dx,
        y: local.dy,
        timestamp: event.timeStamp,
      ),
    );
  }

  @override
  bool get validForMouseTracker => attached;

  @override
  void updateCursor(GCursor cursor) {
    final next = _toFlutterCursor(cursor);
    if (identical(next, _mouseCursor)) return;
    _mouseCursor = next;
    markNeedsPaint();
  }

  static MouseCursor _toFlutterCursor(GCursor cursor) {
    return switch (cursor) {
      GHiddenCursor() => SystemMouseCursors.none,
      GSystemCursor(:final type) => switch (type) {
        GSystemCursorType.auto => MouseCursor.defer,
        GSystemCursorType.basic => SystemMouseCursors.basic,
        GSystemCursorType.click => SystemMouseCursors.click,
        GSystemCursorType.text => SystemMouseCursors.text,
        GSystemCursorType.move => SystemMouseCursors.move,
        GSystemCursorType.grab => SystemMouseCursors.grab,
        GSystemCursorType.grabbing => SystemMouseCursors.grabbing,
        GSystemCursorType.resizeH => SystemMouseCursors.resizeLeftRight,
        GSystemCursorType.resizeV => SystemMouseCursors.resizeUpDown,
      },
      GCursor() => MouseCursor.defer,
    };
  }
}
