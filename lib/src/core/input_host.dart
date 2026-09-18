part of 'package:graphx/src/graphx_impl.dart';

/// Public ingress used by external Stage hosts to feed physical input into
/// GraphX without depending on Flutter's [GraphXView] implementation.
///
/// These methods intentionally live on [GInput] so hosts do not allocate or
/// retain a parallel adapter object. Pointer coordinates are Stage-local.
extension GInputHostDispatch on GInput {
  /// Dispatches a pointer event produced by the owning host.
  ///
  /// Down/move/up/cancel/hover and scroll all use the same canonical pointer
  /// pipeline as [GraphXView].
  void dispatchPointer(GPointerEvent event) {
    pointer._dispatch(event);
  }

  /// Dispatches an enter/exit event for the Stage surface.
  void dispatchPointerBoundary(GPointerBoundaryEvent event) {
    switch (event.type) {
      case GPointerBoundaryEventType.enter:
        pointer._dispatchEnter(event);
      case GPointerBoundaryEventType.exit:
        pointer._dispatchExit(event);
    }
  }

  /// Begins a host-provided pan/zoom gesture in Stage-local coordinates.
  void beginPointerPanZoom({
    required int pointerId,
    required double x,
    required double y,
  }) {
    pointer._beginPanZoom(pointer: pointerId, x: x, y: y);
  }

  /// Updates a host-provided pan/zoom gesture.
  void updatePointerPanZoom({
    required int pointerId,
    required double x,
    required double y,
    required double panX,
    required double panY,
    required double panDeltaX,
    required double panDeltaY,
    required double scale,
    required double rotation,
    required Duration timestamp,
  }) {
    pointer._updatePanZoom(
      pointer: pointerId,
      x: x,
      y: y,
      panX: panX,
      panY: panY,
      panDeltaX: panDeltaX,
      panDeltaY: panDeltaY,
      scale: scale,
      rotation: rotation,
      timestamp: timestamp,
    );
  }

  /// Ends the active host-provided pan/zoom gesture, if any.
  void endPointerPanZoom() {
    pointer._endPanZoom();
  }

  /// Dispatches a raw key event and applies the Stage's semantic shortcut
  /// bindings through the same path used by [GraphXView].
  ///
  /// Returns whether a semantic action handled the key. Hosts can use the
  /// result to decide whether the physical event should continue propagating.
  bool dispatchKey(GKeyEvent event) {
    if (_disposed || !_enabled) return false;
    keyboard._dispatch(event);
    return _gStageFocus[_stage]?.actions._dispatchKey(event) ?? false;
  }

  /// Clears held-key state when the owning host loses keyboard focus without
  /// receiving ordinary key-up events.
  void resetKeyboard() {
    if (_disposed) return;
    keyboard._clear();
  }
}
