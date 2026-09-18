// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Single-pointer long-press recognizer.
///
/// The press is rejected when the pointer moves more than [slop] Stage-space
/// pixels before [delay] elapses. It disposes automatically with [node];
/// explicit [dispose] remains useful when ending recognition earlier.
final class GLongPress implements _GDisposable {
  GLongPress(
    this.node, {
    this.delay = const Duration(milliseconds: 500),
    this.slop = _kGestureSlop,
  }) {
    if (node.isDisposed) {
      throw StateError('Cannot attach GLongPress to a disposed node.');
    }
    if (delay.isNegative) {
      throw ArgumentError.value(delay, 'delay', 'Must not be negative.');
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
  final Duration delay;
  final double slop;

  late final GSignalSubscription _downSub;
  late final GSignalSubscription _moveSub;
  late final GSignalSubscription _upSub;
  late final GSignalSubscription _cancelSub;
  late final GSignalSubscription _nodeDisposeSub;

  GSignal<GNodePointerEvent>? _longPress;
  GSignalView<GNodePointerEvent> get onLongPress => (_longPress ??= GSignal<GNodePointerEvent>());

  Timer? _timer;
  GNodePointerEvent? _downEvent;
  int _pointer = -1;
  double _downX = 0.0;
  double _downY = 0.0;
  bool _disposed = false;

  void _onDown(GNodePointerEvent event) {
    if (!_isGesturePointerDown(event) || _pointer != -1) return;
    _pointer = event.pointer;
    _downEvent = event;
    _downX = event.x;
    _downY = event.y;
    _timer = Timer(delay, _fire);
  }

  void _onMove(GNodePointerEvent event) {
    if (event.pointer != _pointer || _timer == null) return;
    final dx = event.x - _downX;
    final dy = event.y - _downY;
    if (dx * dx + dy * dy > slop * slop) _reset();
  }

  void _onUp(GNodePointerEvent event) {
    if (event.pointer == _pointer) _reset();
  }

  void _onCancel(GNodePointerEvent event) {
    if (event.pointer == _pointer) _reset();
  }

  void _fire() {
    _timer = null;
    final event = _downEvent;
    if (event == null || !_isGestureNodeRoutable(node)) {
      _reset();
      return;
    }
    _longPress?.emit(event);
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _downEvent = null;
    _pointer = -1;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _nodeDisposeSub.cancel();
    _reset();
    _downSub.cancel();
    _moveSub.cancel();
    _upSub.cancel();
    _cancelSub.cancel();
    _longPress?.dispose();
  }
}
