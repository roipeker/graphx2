part of 'package:graphx/src/graphx_impl.dart';

/// Flash-style direct pointer following for scene nodes.
///
/// This is behavior, not gesture recognition: [startDrag] follows a pointer
/// until [stopDrag] is called. [GDrag] remains the threshold-based recognizer.
extension GNodeDrag on GNode {
  /// Starts moving this node with a pointer.
  ///
  /// When [pointer] is omitted inside a node pointer callback, the currently
  /// dispatched pointer is used. Outside dispatch it follows the Stage cursor.
  /// [bounds] constrain this node's x/y registration point in parent space.
  ///
  /// With [lockCenter] false the initial grab offset is preserved. With it
  /// true the node registration point is locked directly to the pointer.
  void startDrag({int? pointer, bool lockCenter = false, GBounds? bounds}) {
    if (isDisposed) {
      throw StateError('Cannot drag a disposed node.');
    }
    if (!isAttached) {
      throw StateError('startDrag() requires an attached node.');
    }
    if (bounds != null && bounds.isEmpty) {
      throw ArgumentError.value(bounds, 'bounds', 'Must not be empty.');
    }

    final nodePointer = this.pointer;
    final current = nodePointer._currentEvent;
    final resolvedPointer = pointer ?? current?.pointer;

    double? x;
    double? y;
    GRenderView? renderView;
    if (current != null &&
        (resolvedPointer == null || current.pointer == resolvedPointer)) {
      x = current.x;
      y = current.y;
      renderView = current._renderView;
    } else if (resolvedPointer != null) {
      final state = stage.pointer.pointer(resolvedPointer);
      if (state == null) {
        throw StateError('Pointer $resolvedPointer is not available.');
      }
      x = state.x;
      y = state.y;
      renderView = _inputRenderViewAt(stage, x, y);
    } else if (stage.pointer.isInside) {
      x = stage.pointer.x;
      y = stage.pointer.y;
      renderView = _inputRenderViewAt(stage, x, y);
    }

    (nodePointer._dragBinding ??= _GNodeDragBinding(this)).start(
      stage: stage,
      pointer: resolvedPointer,
      x: x,
      y: y,
      renderView: renderView,
      lockCenter: lockCenter,
      bounds: bounds,
    );
  }

  /// Stops direct pointer following started by [startDrag].
  void stopDrag() => _pointer?._dragBinding?.stop();

  bool get isDragging => _pointer?._dragBinding?.isActive ?? false;
}

final class _GNodeDragBinding implements _GDisposable {
  _GNodeDragBinding(this.node);

  final GNode node;
  final GPoint _worldPoint = GPoint();
  final GPoint _parentPoint = GPoint();

  GStage? _stage;
  GRenderView? _renderView;
  int? _pointer;
  bool _lockCenter = false;
  bool _anchored = false;
  double _offsetX = 0.0;
  double _offsetY = 0.0;

  bool _hasBounds = false;
  double _x1 = 0.0;
  double _y1 = 0.0;
  double _x2 = 0.0;
  double _y2 = 0.0;

  GSignalSubscription? _moveSub;
  GSignalSubscription? _hoverSub;
  GSignalSubscription? _enterSub;
  GSignalSubscription? _cancelSub;
  GSignalSubscription? _detachSub;

  bool _active = false;
  bool _disposed = false;

  bool get isActive => _active;

  void start({
    required GStage stage,
    required int? pointer,
    required double? x,
    required double? y,
    required GRenderView? renderView,
    required bool lockCenter,
    required GBounds? bounds,
  }) {
    stop();
    if (_disposed) {
      throw StateError('Cannot restart a disposed drag binding.');
    }

    _stage = stage;
    _renderView = renderView;
    _pointer = pointer;
    _lockCenter = lockCenter;
    _hasBounds = bounds != null;
    if (bounds != null) {
      _x1 = bounds.x1;
      _y1 = bounds.y1;
      _x2 = bounds.x2;
      _y2 = bounds.y2;
    }

    final stagePointer = stage.pointer;
    _moveSub = stagePointer.onMove.add(_onMove);
    _hoverSub = stagePointer.onHover.add(_onMove);
    _enterSub = stagePointer.onEnter.add(_onEnter);
    _cancelSub = stagePointer.onCancel.add(_onCancel);
    _detachSub = node.signals.onDetached.add(stop);
    _active = true;

    if (x != null && y != null) _update(x, y);
  }

  void _onMove(GPointerEvent event) {
    if (_pointer != null && event.pointer != _pointer) return;
    _update(event.x, event.y);
  }

  void _onEnter(GPointerBoundaryEvent event) {
    if (_pointer != null && event.pointer != _pointer) return;
    _update(event.x, event.y);
  }

  void _onCancel(GPointerEvent event) {
    if (_pointer == null || event.pointer == _pointer) stop();
  }

  void _update(double stageX, double stageY) {
    if (!_active || node.isDisposed || !node.isAttached) return;
    final stage = _stage;
    if (stage == null || !identical(node._stage, stage)) {
      stop();
      return;
    }

    var worldX = stageX;
    var worldY = stageY;
    final renderView = _renderView;
    if (renderView != null) {
      if (!renderView.enabled ||
          !renderView.stageToWorldInto(stageX, stageY, _worldPoint)) {
        return;
      }
      worldX = _worldPoint.x;
      worldY = _worldPoint.y;
    }

    final parent = node._parent;
    if (parent == null) {
      _parentPoint.set(worldX, worldY);
    } else if (!parent.globalToLocalInto(worldX, worldY, _parentPoint)) {
      return;
    }

    if (!_anchored) {
      _anchored = true;
      if (!_lockCenter) {
        _offsetX = node.x - _parentPoint.x;
        _offsetY = node.y - _parentPoint.y;
      }
    }

    var x = _parentPoint.x + _offsetX;
    var y = _parentPoint.y + _offsetY;
    if (_hasBounds) {
      x = x.clamp(_x1, _x2);
      y = y.clamp(_y1, _y2);
    }
    node.setPosition(x, y);
  }

  void stop() {
    if (!_active) return;
    _active = false;
    _moveSub?.cancel();
    _hoverSub?.cancel();
    _enterSub?.cancel();
    _cancelSub?.cancel();
    _detachSub?.cancel();
    _moveSub = _hoverSub = _enterSub = _cancelSub = _detachSub = null;
    _stage = null;
    _renderView = null;
    _pointer = null;
    _anchored = false;
    _hasBounds = false;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
  }
}
