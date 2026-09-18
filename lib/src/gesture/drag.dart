// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Single-pointer drag recognizer.
///
/// Recognition starts after [slop] Stage-space pixels of movement. Pointer
/// routing remains owned by the node pointer system; this class only interprets
/// the already-routed press sequence. It disposes automatically with [node];
/// explicit [dispose] remains useful when ending recognition earlier.
///
/// [GDragEvent] instances are reused during dispatch. Copy values that must be
/// retained after a callback returns.
final class GDrag implements _GDisposable {
  GDrag(this.node, {this.slop = _kGestureSlop}) {
    if (node.isDisposed) {
      throw StateError('Cannot attach GDrag to a disposed node.');
    }
    if (!slop.isFinite || slop < 0.0) {
      throw ArgumentError.value(slop, 'slop', 'Must be finite and >= 0.');
    }
    final pointer = node.pointer;
    _downSub = pointer.onDown.add(_onDown);
    _moveSub = pointer.onMove.add(_onMove);
    _upSub = pointer.onUp.add(_onUp);
    _cancelSub = pointer.onCancel.add(_onCancel);
    _nodeDisposeSub = node.signals.onDispose.add(dispose);
  }

  final GNode node;
  final double slop;

  late final GSignalSubscription _downSub;
  late final GSignalSubscription _moveSub;
  late final GSignalSubscription _upSub;
  late final GSignalSubscription _cancelSub;
  late final GSignalSubscription _nodeDisposeSub;

  GSignal<GDragEvent>? _start;
  GSignal<GDragEvent>? _update;
  GSignal<GDragEvent>? _end;
  GSignal<GDragEvent>? _cancel;

  GSignal<GDragEvent> get onStart => (_start ??= GSignal<GDragEvent>());
  GSignal<GDragEvent> get onUpdate => (_update ??= GSignal<GDragEvent>());
  GSignal<GDragEvent> get onEnd => (_end ??= GSignal<GDragEvent>());
  GSignal<GDragEvent> get onCancel => (_cancel ??= GSignal<GDragEvent>());

  final GDragEvent _event = GDragEvent._();

  int _pointer = -1;
  double _startX = 0.0;
  double _startY = 0.0;
  double _lastX = 0.0;
  double _lastY = 0.0;
  bool _dragging = false;
  bool _disposed = false;

  bool get isDragging => _dragging;

  void _onDown(GNodePointerEvent event) {
    if (!_isGesturePointerDown(event) || _pointer != -1) return;
    _pointer = event.pointer;
    _startX = _lastX = event.x;
    _startY = _lastY = event.y;
  }

  void _onMove(GNodePointerEvent event) {
    if (event.pointer != _pointer) return;

    final x = event.x;
    final y = event.y;
    if (!_dragging) {
      final dx = x - _startX;
      final dy = y - _startY;
      if (dx * dx + dy * dy <= slop * slop) return;
      _dragging = true;
      _writeEvent(event, x - _startX, y - _startY);
      _start?.emit(_event);
      _update?.emit(_event);
      _lastX = x;
      _lastY = y;
      return;
    }

    _writeEvent(event, x - _lastX, y - _lastY);
    _update?.emit(_event);
    _lastX = x;
    _lastY = y;
  }

  void _onUp(GNodePointerEvent event) {
    if (event.pointer != _pointer) return;
    if (_dragging) {
      _writeEvent(event, event.x - _lastX, event.y - _lastY);
      _end?.emit(_event);
    }
    _reset();
  }

  void _onCancel(GNodePointerEvent event) {
    if (event.pointer != _pointer) return;
    if (_dragging) {
      _writeEvent(event, event.x - _lastX, event.y - _lastY);
      _cancel?.emit(_event);
    }
    _reset();
  }

  void _writeEvent(GNodePointerEvent source, double dx, double dy) {
    _event
      .._node = node
      .._source = source
      .._startX = _startX
      .._startY = _startY
      .._x = source.x
      .._y = source.y
      .._deltaX = dx
      .._deltaY = dy;
  }

  void _reset() {
    _pointer = -1;
    _dragging = false;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _nodeDisposeSub.cancel();
    _downSub.cancel();
    _moveSub.cancel();
    _upSub.cancel();
    _cancelSub.cancel();
    _start?.dispose();
    _update?.dispose();
    _end?.dispose();
    _cancel?.dispose();
    _reset();
  }
}

/// Reused drag payload with Stage-space coordinates and deltas.
final class GDragEvent {
  GDragEvent._();

  GNode? _node;
  GNodePointerEvent? _source;
  double _startX = 0.0;
  double _startY = 0.0;
  double _x = 0.0;
  double _y = 0.0;
  double _deltaX = 0.0;
  double _deltaY = 0.0;

  GNode get node => _node!;
  GNodePointerEvent get source => _source!;
  int get pointer => source.pointer;
  GPointerDeviceKind get kind => source.kind;

  double get startX => _startX;
  double get startY => _startY;
  double get x => _x;
  double get y => _y;
  double get deltaX => _deltaX;
  double get deltaY => _deltaY;
  double get totalDeltaX => _x - _startX;
  double get totalDeltaY => _y - _startY;
}
