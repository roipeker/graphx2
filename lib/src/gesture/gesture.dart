part of 'package:graphx/src/graphx_impl.dart';

const double _kGestureSlop = 8.0;

bool _isGesturePointerDown(GNodePointerEvent event) {
  final button = event.button;
  return button == 0 || button == kPrimaryButton;
}

bool _isGestureNodeRoutable(GNode node) {
  if (node.isDisposed || !node.isAttached) return false;
  GNode? current = node;
  while (current != null) {
    if (!current._active || !current._visible) return false;
    final pointer = current._pointer;
    if (pointer != null && !pointer._enabled) return false;
    current = current._parent;
  }
  return true;
}
