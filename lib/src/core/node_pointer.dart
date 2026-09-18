part of 'package:graphx/src/graphx_impl.dart';

/// Pointer behavior and signals for one scene node.
///
/// [enabled] gates this node and its complete subtree. [children] controls
/// whether descendants may become independent pointer targets. Both default to
/// true; actual hit-test participation remains demand-driven by pointer signals
/// and [cursor].
final class GNodePointer implements _GDisposable {
  GNodePointer._(this._node);

  final GNode _node;

  bool _enabled = true;
  bool _children = true;
  bool _respectsRenderMask = true;
  bool _hasInterest = false;
  bool _hasHoverInterest = false;
  bool _disposed = false;
  GHitArea? _hitArea;
  GCursor? _cursor;

  GSignal<GNodePointerEvent>? _down;
  GSignal<GNodePointerEvent>? _move;
  GSignal<GNodePointerEvent>? _up;
  GSignal<GNodePointerEvent>? _cancel;
  GSignal<GNodePointerEvent>? _enter;
  GSignal<GNodePointerEvent>? _exit;
  GSignal<GNodePointerEvent>? _scroll;
  GSignal<GNodePointerEvent>? _tap;

  _GNodeDragBinding? _dragBinding;
  GNodePointerEvent? _currentEvent;

  /// Disables pointer routing for this node and its entire subtree when false.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _node._stage?._nodePointerRouter?._markSceneChanged();
  }

  /// Whether a [GRenderGroup.renderMask] also filters this pointer subtree.
  ///
  /// This defaults to true. Advanced custom-render hosts can set it to false
  /// when a render group exists only to suppress the normal renderer while the
  /// same retained descendants remain interactive through another render path.
  bool get respectsRenderMask => _respectsRenderMask;
  set respectsRenderMask(bool value) {
    if (_respectsRenderMask == value) return;
    _respectsRenderMask = value;
    _node._stage?._nodePointerRouter?._markSceneChanged();
  }

  /// Whether descendants may become independent pointer targets.
  ///
  /// When false, visible descendant content contributes to this node's hit,
  /// but the node itself becomes the target. This is useful for composite
  /// controls made from background, icon and label nodes.
  bool get children => _children;
  set children(bool value) {
    if (_children == value) return;
    _children = value;
    _node._stage?._nodePointerRouter?._markSceneChanged();
  }

  /// Cursor while this node or its targeted descendants are hovered.
  ///
  /// Null inherits from the nearest ancestor cursor and ultimately falls back
  /// to [GPointerManager.cursor]. Cursor-only nodes participate in hit testing
  /// without requiring pointer signal listeners.
  GCursor? get cursor => _cursor;
  set cursor(GCursor? value) {
    if (identical(_cursor, value)) return;
    _cursor = value;
    _refreshInterest();
  }

  /// Optional local-space pointer geometry override for this node.
  ///
  /// This never changes visual bounds, rendering, layout, or geometry-only
  /// scene inspection. With [children] false it becomes authoritative for the
  /// composite target instead of descendant visual geometry.
  GHitArea? get hitArea => _hitArea;
  set hitArea(GHitArea? value) {
    if (identical(_hitArea, value)) return;
    _hitArea = value;
    _node._stage?._nodePointerRouter?._markSceneChanged();
  }

  /// Reconciles stationary hover after mutating a custom [hitArea] in place.
  void invalidateHitArea() {
    if (_hitArea == null) return;
    _node._stage?._nodePointerRouter?._markSceneChanged();
  }

  GSignalView<GNodePointerEvent> get onDown => (_down ??= _signal());
  GSignalView<GNodePointerEvent> get onMove => (_move ??= _signal());
  GSignalView<GNodePointerEvent> get onUp => (_up ??= _signal());
  GSignalView<GNodePointerEvent> get onCancel => (_cancel ??= _signal());
  GSignalView<GNodePointerEvent> get onEnter => (_enter ??= _signal());
  GSignalView<GNodePointerEvent> get onExit => (_exit ??= _signal());
  GSignalView<GNodePointerEvent> get onScroll => (_scroll ??= _signal());

  /// Primary tap convenience synthesized from the routed press sequence.
  ///
  /// Recognition is demand-gated, uses a small Stage-space movement slop and
  /// keeps the same target/bubbling semantics as the underlying pointer events.
  GSignalView<GNodePointerEvent> get onTap => (_tap ??= _signal());

  GSignal<GNodePointerEvent> _signal() => GSignal<GNodePointerEvent>(
    onListenerCountChanged: (_) => _refreshInterest(),
  );

  void _refreshInterest() {
    final next =
        _cursor != null ||
        (_down?.hasListeners ?? false) ||
        (_move?.hasListeners ?? false) ||
        (_up?.hasListeners ?? false) ||
        (_cancel?.hasListeners ?? false) ||
        (_enter?.hasListeners ?? false) ||
        (_exit?.hasListeners ?? false) ||
        (_scroll?.hasListeners ?? false) ||
        (_tap?.hasListeners ?? false);
    if (_hasInterest != next) {
      _hasInterest = next;
      _node._adjustPointerSubtreeInterest(next ? 1 : -1);
    }

    final hover =
        _cursor != null ||
        (_enter?.hasListeners ?? false) ||
        (_exit?.hasListeners ?? false);
    if (_hasHoverInterest != hover) {
      _hasHoverInterest = hover;
      _node._adjustPointerHoverSubtreeInterest(hover ? 1 : -1);
    }

    final stage = _node._stage;
    if (stage == null) return;
    if (next) {
      stage._ensureNodePointerRouter()._markSceneChanged();
    } else {
      stage._nodePointerRouter?._markSceneChanged();
    }
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dragBinding?.dispose();
    _down?.dispose();
    _move?.dispose();
    _up?.dispose();
    _cancel?.dispose();
    _enter?.dispose();
    _exit?.dispose();
    _scroll?.dispose();
    _tap?.dispose();
    _currentEvent = null;
    _hitArea = null;
    _cursor = null;
  }
}

extension GNodeHitArea on GNode {
  /// Pointer-only hit override in this node's local coordinate space.
  GHitArea? get hitArea => _pointer?._hitArea;
  set hitArea(GHitArea? value) => pointer.hitArea = value;

  /// Call after mutating a custom hit-area implementation in place.
  void invalidateHitArea() => _pointer?.invalidateHitArea();
}

/// Node-routed pointer event.
///
/// [x]/[y] remain raw Stage-surface coordinates so bubbling, gesture slop and
/// camera navigation are independent of zoom. [worldPositionInto] resolves the
/// view selected for this routed sequence; [localPositionInto] then converts
/// that world point through the same interaction-coordinate mapping used by hit
/// testing, including projected/custom spaces.
final class GNodePointerEvent {
  const GNodePointerEvent._(this.source, this.target, [this._renderView]);

  final GPointerEvent source;
  final GNode target;
  final GRenderView? _renderView;

  int get pointer => source.pointer;
  GPointerDeviceKind get kind => source.kind;
  double get x => source.x;
  double get y => source.y;
  double get deltaX => source.deltaX;
  double get deltaY => source.deltaY;
  int get button => source.button;
  int get buttons => source.buttons;
  double get scrollX => source.scrollX;
  double get scrollY => source.scrollY;
  GPointerScrollSource? get scrollSource => source.scrollSource;
  Duration get timestamp => source.timestamp;

  /// Explicit render view that routed this event, or null for the identity view.
  GRenderView? get renderView => _renderView;

  bool worldPositionInto(GPoint out) {
    final view = _renderView;
    if (view == null) {
      out.set(x, y);
      return true;
    }
    return view.stageToWorldInto(x, y, out);
  }

  GPoint? worldPosition() {
    final out = GPoint();
    return worldPositionInto(out) ? out : null;
  }

  bool localPositionInto(GNode node, GPoint out) {
    if (!worldPositionInto(out)) return false;
    return _interactionWorldToLocalInto(node, out.x, out.y, out);
  }

  GPoint? localPosition(GNode node) {
    final out = GPoint();
    return localPositionInto(node, out) ? out : null;
  }
}

enum _GNodePointerSignal { down, move, up, cancel, enter, exit, scroll, tap }

final class _GNodePointerRouter implements _GDisposable {
  _GNodePointerRouter(this.stage) {
    final pointer = stage.pointer;
    _subscriptions = <GSignalSubscription>[
      pointer.onDown.add(_handleDown),
      pointer.onMove.add(_handleMove),
      pointer.onHover.add(_handleHover),
      pointer.onUp.add(_handleUp),
      pointer.onCancel.add(_handleCancel),
      pointer.onScroll.add(_handleScroll),
      pointer.onEnter.add(_handleStageEnter),
      pointer.onExit.add(_handleStageExit),
    ];
  }

  final GStage stage;
  late final List<GSignalSubscription> _subscriptions;
  final Map<int, GNode> _captures = <int, GNode>{};
  final Map<int, GRenderView> _captureViews = <int, GRenderView>{};
  final List<GNode> _hoverPath = <GNode>[];
  final List<GNode> _nextHoverPath = <GNode>[];
  Map<int, _GPointerTapCandidate>? _tapCandidates;

  GNode? _hoverTarget;
  GRenderView? _hoverView;
  GPointerEvent? _lastHoverEvent;
  bool _sceneDirtyScheduled = false;
  bool _disposed = false;

  void _markSceneChanged() {
    if (_disposed ||
        _sceneDirtyScheduled ||
        !stage.pointer.isInside ||
        (stage.root._pointerHoverSubtreeInterest == 0 &&
            _hoverTarget == null)) {
      return;
    }
    _sceneDirtyScheduled = true;
    scheduleMicrotask(() {
      _sceneDirtyScheduled = false;
      if (_disposed || stage.isDisposed) return;
      _reconcileHover();
    });
  }

  void _handleDown(GPointerEvent event) {
    if (_supportsHover(event.kind)) _reconcileHover(event);
    final view = _renderViewFor(event);
    final target = _resolvePointerHit(stage, event.x, event.y);
    if (target == null) return;

    // A down target owns this pointer until up/cancel. This keeps drags,
    // sliders and similar press interactions receiving move/up even after
    // the pointer leaves the node's hit area; hover still follows geometry.
    _captures[event.pointer] = target;
    if (view != null) _captureViews[event.pointer] = view;
    _dispatchBubble(target, _GNodePointerSignal.down, event, view);

    if (_hasTapInterest(target) && _isTapPointerDown(event)) {
      (_tapCandidates ??= <int, _GPointerTapCandidate>{})[event.pointer] =
          _GPointerTapCandidate(target, event.x, event.y);
    }
  }

  void _handleMove(GPointerEvent event) {
    if (_supportsHover(event.kind)) _reconcileHover(event);
    _updateTapCandidate(event);
    final captured = _captured(event.pointer);
    final target = captured ?? _resolvePointerHit(stage, event.x, event.y);
    if (target == null) return;
    final view = captured == null
        ? _renderViewFor(event)
        : _captureViews[event.pointer];
    _dispatchBubble(target, _GNodePointerSignal.move, event, view);
  }

  void _handleHover(GPointerEvent event) {
    _reconcileHover(event);
    final target = _hoverTarget;
    if (target != null) {
      _dispatchBubble(target, _GNodePointerSignal.move, event, _hoverView);
    }
  }

  void _handleUp(GPointerEvent event) {
    final captured = _captured(event.pointer);
    final view = captured == null
        ? _renderViewFor(event)
        : _captureViews[event.pointer];
    final target = captured ?? _resolvePointerHit(stage, event.x, event.y);
    if (target != null) {
      _dispatchBubble(target, _GNodePointerSignal.up, event, view);
    }

    final candidate = _tapCandidates?.remove(event.pointer);
    if (candidate != null &&
        identical(captured, candidate.target) &&
        _isRoutable(candidate.target, view)) {
      _dispatchBubble(candidate.target, _GNodePointerSignal.tap, event, view);
    }

    _captures.remove(event.pointer);
    _captureViews.remove(event.pointer);
    if (_supportsHover(event.kind)) _reconcileHover(event);
  }

  void _handleCancel(GPointerEvent event) {
    _tapCandidates?.remove(event.pointer);
    final target = _captured(event.pointer);
    final view = _captureViews[event.pointer];
    if (target != null) {
      _dispatchBubble(target, _GNodePointerSignal.cancel, event, view);
    }
    _captures.remove(event.pointer);
    _captureViews.remove(event.pointer);
    if (_supportsHover(event.kind)) _reconcileHover(event);
  }

  void _handleScroll(GPointerEvent event) {
    if (_supportsHover(event.kind)) _reconcileHover(event);
    final target = _hoverTarget ?? _resolvePointerHit(stage, event.x, event.y);
    if (target != null) {
      final view = _hoverTarget == null ? _renderViewFor(event) : _hoverView;
      _dispatchBubble(target, _GNodePointerSignal.scroll, event, view);
    }
  }

  void _handleStageEnter(GPointerBoundaryEvent event) {
    final source = GPointerEvent(
      type: GPointerEventType.hover,
      pointer: event.pointer,
      kind: event.kind,
      x: event.x,
      y: event.y,
      deltaX: 0.0,
      deltaY: 0.0,
      buttons: stage.pointer.buttons,
      timestamp: event.timestamp,
    );
    _reconcileHover(source);
  }

  void _handleStageExit(GPointerBoundaryEvent event) {
    final source = GPointerEvent(
      type: GPointerEventType.hover,
      pointer: event.pointer,
      kind: event.kind,
      x: event.x,
      y: event.y,
      deltaX: 0.0,
      deltaY: 0.0,
      buttons: stage.pointer.buttons,
      timestamp: event.timestamp,
    );
    _lastHoverEvent = source;
    _setHoverTarget(null, source, null);
  }

  void _updateTapCandidate(GPointerEvent event) {
    final candidates = _tapCandidates;
    if (candidates == null) return;
    final candidate = candidates[event.pointer];
    if (candidate == null) return;
    final dx = event.x - candidate.x;
    final dy = event.y - candidate.y;
    if (dx * dx + dy * dy > _kGestureSlop * _kGestureSlop) {
      candidates.remove(event.pointer);
    }
  }

  bool _hasTapInterest(GNode node) {
    GNode? current = node;
    while (current != null) {
      if (current._pointer?._tap?.hasListeners ?? false) return true;
      current = current._parent;
    }
    return false;
  }

  static bool _isTapPointerDown(GPointerEvent event) {
    final button = event.button;
    return button == 0 || button == kPrimaryButton;
  }

  GNode? _captured(int pointer) {
    final target = _captures[pointer];
    if (target == null) return null;
    final view = _captureViews[pointer];
    if (_isRoutable(target, view)) return target;
    _captures.remove(pointer);
    _captureViews.remove(pointer);
    return null;
  }

  bool _isRoutable(GNode node, [GRenderView? view]) {
    if (node.isDisposed || !node.isAttached || !identical(node._stage, stage)) {
      return false;
    }
    if (view != null && (!view.enabled || !view.inputEnabled)) return false;
    final renderMaskBits = view?.mask.bits ?? GRenderMask.all.bits;
    GNode? current = node;
    while (current != null) {
      if (!current._active || !current._visible) return false;
      final pointer = current._pointer;
      if (current is GRenderGroup &&
          (current._renderMask.bits & renderMaskBits) == 0 &&
          (pointer?._respectsRenderMask ?? true)) {
        return false;
      }
      if (pointer != null && !pointer._enabled) return false;
      current = current._parent;
    }
    return true;
  }

  GRenderView? _renderViewFor(GPointerEvent event) =>
      _inputRenderViewAt(stage, event.x, event.y);

  void _reconcileHover([GPointerEvent? event]) {
    if (_disposed) return;
    if (event != null) _lastHoverEvent = event;
    final source = event ?? _lastHoverEvent;
    final next =
        stage.pointer.isInside && stage.root._pointerSubtreeInterest != 0
        ? _resolvePointerHit(stage, stage.pointer.x, stage.pointer.y)
        : null;
    final nextView = source == null
        ? _inputRenderViewAt(stage, stage.pointer.x, stage.pointer.y)
        : _renderViewFor(source);
    if (source == null) {
      _hoverPath.clear();
      _writePath(next, _hoverPath);
      _hoverTarget = next;
      _hoverView = next == null ? null : nextView;
      _syncCursor(next);
      return;
    }
    _setHoverTarget(next, source, nextView);
  }

  void _setHoverTarget(
    GNode? next,
    GPointerEvent source,
    GRenderView? nextView,
  ) {
    final previous = _hoverTarget;
    final previousView = _hoverView;
    if (identical(previous, next) && identical(previousView, nextView)) {
      _syncCursor(next);
      return;
    }

    final nextPath = _nextHoverPath;
    nextPath.clear();
    _writePath(next, nextPath);
    final oldPath = _hoverPath;
    var common = 0;
    if (identical(previousView, nextView)) {
      final commonEnd = math.min(oldPath.length, nextPath.length);
      while (common < commonEnd &&
          identical(oldPath[common], nextPath[common])) {
        common++;
      }
    }

    final exitEvent = previous == null
        ? null
        : GNodePointerEvent._(source, previous, previousView);
    for (var i = oldPath.length - 1; i >= common; --i) {
      _emitDirect(oldPath[i], _GNodePointerSignal.exit, exitEvent!);
    }
    final enterEvent = next == null
        ? null
        : GNodePointerEvent._(source, next, nextView);
    for (var i = common; i < nextPath.length; ++i) {
      _emitDirect(nextPath[i], _GNodePointerSignal.enter, enterEvent!);
    }
    oldPath
      ..clear()
      ..addAll(nextPath);
    nextPath.clear();
    _hoverTarget = next;
    _hoverView = next == null ? null : nextView;
    _syncCursor(next);
  }

  void _syncCursor(GNode? node) {
    while (node != null) {
      final cursor = node._pointer?._cursor;
      if (cursor != null) {
        stage.pointer._setHoverCursor(cursor);
        return;
      }
      node = node._parent;
    }
    stage.pointer._setHoverCursor(null);
  }

  void _writePath(GNode? node, List<GNode> out) {
    while (node != null) {
      out.add(node);
      node = node._parent;
    }
    for (var left = 0, right = out.length - 1; left < right; left++, right--) {
      final value = out[left];
      out[left] = out[right];
      out[right] = value;
    }
  }

  void _dispatchBubble(
    GNode target,
    _GNodePointerSignal signal,
    GPointerEvent source,
    GRenderView? view,
  ) {
    final event = GNodePointerEvent._(source, target, view);
    GNode? node = target;
    while (node != null) {
      final next = node._parent;
      final pointer = node._pointer;
      if (pointer != null && pointer._enabled) _emit(pointer, signal, event);
      node = next;
    }
  }

  void _emitDirect(
    GNode node,
    _GNodePointerSignal signal,
    GNodePointerEvent event,
  ) {
    final pointer = node._pointer;
    if (pointer == null) return;
    _emit(pointer, signal, event);
  }

  void _emit(
    GNodePointer pointer,
    _GNodePointerSignal signal,
    GNodePointerEvent event,
  ) {
    final previous = pointer._currentEvent;
    pointer._currentEvent = event;
    try {
      switch (signal) {
        case _GNodePointerSignal.down:
          pointer._down?.emit(event);
        case _GNodePointerSignal.move:
          pointer._move?.emit(event);
        case _GNodePointerSignal.up:
          pointer._up?.emit(event);
        case _GNodePointerSignal.cancel:
          pointer._cancel?.emit(event);
        case _GNodePointerSignal.enter:
          pointer._enter?.emit(event);
        case _GNodePointerSignal.exit:
          pointer._exit?.emit(event);
        case _GNodePointerSignal.scroll:
          pointer._scroll?.emit(event);
        case _GNodePointerSignal.tap:
          pointer._tap?.emit(event);
      }
    } finally {
      pointer._currentEvent = previous;
    }
  }

  static bool _supportsHover(GPointerDeviceKind kind) =>
      kind == GPointerDeviceKind.mouse ||
      kind == GPointerDeviceKind.stylus ||
      kind == GPointerDeviceKind.invertedStylus;

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stage.pointer._setHoverCursor(null);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _captures.clear();
    _captureViews.clear();
    _tapCandidates?.clear();
    _hoverPath.clear();
    _nextHoverPath.clear();
    _hoverTarget = null;
    _hoverView = null;
    _lastHoverEvent = null;
  }
}

/// Legacy marker kept for source compatibility while node pointer behavior is
/// owned by [GNodePointer].
mixin GNodeInput {}
