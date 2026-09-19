// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

// ================================
//   POINTER
//   mouse, trackpad, touches
// ================================
enum GPointerEventType { down, move, up, cancel, hover, scroll }

enum GPointerBoundaryEventType { enter, exit }

enum GPointerDeviceKind {
  mouse,
  touch,
  stylus,
  invertedStylus,
  trackpad,
  unknown,
}

enum GPointerScrollSource { wheel, continuous }

/// This event is used for GraphX stage signal exit/enter.
/// when pointer enters/leaves into the GraphXView area.
final class GPointerBoundaryEvent {
  const GPointerBoundaryEvent({
    required this.type,
    required this.pointer,
    required this.kind,
    required this.x,
    required this.y,
    required this.timestamp,
  });

  final int pointer;
  final GPointerDeviceKind kind;
  final GPointerBoundaryEventType type;

  final double x;
  final double y;

  /// Stage-space alias for [x].
  double get stageX => x;

  /// Stage-space alias for [y].
  double get stageY => y;

  final Duration timestamp;

  @override
  String toString() {
    final out = GDebugString('GPointerBoundary');
    out.value('${kind.name}.${type.name}');
    out.field('@', '${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}');

    if (kind != GPointerDeviceKind.mouse) {
      out.field('id', pointer);
    }

    return out.toString();
  }
}

final class GPointerEvent {
  const GPointerEvent({
    required this.type,
    required this.pointer,
    required this.kind,
    required this.x,
    required this.y,
    required this.deltaX,
    required this.deltaY,
    required this.buttons,
    required this.timestamp,
    this.button = 0,
    this.scrollX = 0.0,
    this.scrollY = 0.0,
    this.scrollSource,
  });

  final GPointerEventType type;
  final int pointer;
  final GPointerDeviceKind kind;

  final double x;
  final double y;

  /// Stage-space alias for [x].
  double get stageX => x;

  /// Stage-space alias for [y].
  double get stageY => y;

  final double deltaX;
  final double deltaY;

  /// Button responsible for a down/up transition.
  ///
  /// 0 for events where no individual button changed.
  final int button;

  /// Bitmask of buttons currently held.
  final int buttons;

  final double scrollX;
  final double scrollY;
  final GPointerScrollSource? scrollSource;

  final Duration timestamp;

  bool get isDown => type == GPointerEventType.down;

  bool get isMove => type == GPointerEventType.move;

  bool get isUp => type == GPointerEventType.up;

  bool get isHover => type == GPointerEventType.hover;

  bool get isScroll => type == GPointerEventType.scroll;

  @override
  String toString() {
    final out = GDebugString('GPointerEvent');

    if (isScroll) {
      out.value('${scrollSource?.name ?? kind.name}.scroll');
    } else {
      out.value('${kind.name}.${type.name}');
    }

    out.field('@', '${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}');

    if ((isMove || isHover) && (deltaX != 0.0 || deltaY != 0.0)) {
      out.field(
        'Δ',
        '${deltaX.toStringAsFixed(1)},${deltaY.toStringAsFixed(1)}',
      );
    }

    if (isScroll) {
      out.field(
        'scroll',
        '${scrollX.toStringAsFixed(1)},${scrollY.toStringAsFixed(1)}',
      );
    }

    if ((isDown || isUp) && button != 0) {
      out.value(_debugButtonName(button));
    }

    if (kind != GPointerDeviceKind.mouse) {
      out.field('id', pointer);
    }

    return out.toString();
  }
}

String _debugButtonName(int button) {
  if (button == kPrimaryButton) return 'primary';
  if (button == kSecondaryButton) return 'secondary';
  if (button == kTertiaryButton) return 'middle';
  return 'button=$button';
}

// sessions[id] tracks pointer (for multitouch)
final class GPointerState {
  GPointerState._(this.pointer);

  final int pointer;

  GPointerDeviceKind kind = GPointerDeviceKind.unknown;

  double x = 0.0;
  double y = 0.0;

  /// Stage-space alias for [x].
  double get stageX => x;

  /// Stage-space alias for [y].
  double get stageY => y;

  // Accumulated between Stage ticks.
  double deltaX = 0.0;
  double deltaY = 0.0;

  int buttons = 0;
  bool down = false;

  int _pressedFrame = -1;
  int _releasedFrame = -1;

  bool pressedOnFrame(int frame) => _pressedFrame == frame;

  bool releasedOnFrame(int frame) => _releasedFrame == frame;
}

final class GPointerPanZoomState {
  bool active = false;
  int pointer = -1;

  double x = 0.0;
  double y = 0.0;

  /// Stage-space alias for [x].
  double get stageX => x;

  /// Stage-space alias for [y].
  double get stageY => y;

  double panX = 0.0;
  double panY = 0.0;

  double panDeltaX = 0.0;
  double panDeltaY = 0.0;

  double scale = 1.0;
  double scaleDelta = 1.0;

  double rotation = 0.0;
  double rotationDelta = 0.0;

  void _reset() {
    active = false;
    pointer = -1;
    x = 0.0;
    y = 0.0;
    panX = 0.0;
    panY = 0.0;
    panDeltaX = 0.0;
    panDeltaY = 0.0;
    scale = 1.0;
    scaleDelta = 1.0;
    rotation = 0.0;
    rotationDelta = 0.0;
  }

  @override
  String toString() {
    final out = GDebugString('GPointerPanZoom');
    out.value(active ? 'active' : 'inactive');
    if (!active) {
      return out.toString();
    }
    out.field('@', '${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}');
    if (panDeltaX != 0.0 || panDeltaY != 0.0) {
      out.field(
        'Δpan',
        '${panDeltaX.toStringAsFixed(1)},${panDeltaY.toStringAsFixed(1)}',
      );
    }
    if (scale != 1.0 || scaleDelta != 1.0) {
      out.field('scale', scale.toStringAsFixed(3));
      if (scaleDelta != 1.0) {
        out.field('Δ', scaleDelta.toStringAsFixed(3));
      }
    }
    if (rotation != 0.0 || rotationDelta != 0.0) {
      out.field('rot', rotation.toStringAsFixed(3));
      if (rotationDelta != 0.0) {
        out.field('Δ', rotationDelta.toStringAsFixed(3));
      }
    }
    return out.toString();
  }
}

class GPointerManager implements _GDisposable {
  GPointerManager._(this._input);

  //==========================================
  // Enter/Exit stage bounds.
  //==========================================
  bool _inside = false;
  GSignal<GPointerBoundaryEvent>? _enter;
  GSignal<GPointerBoundaryEvent>? _exit;

  bool get isInside => _inside;
  GSignal<GPointerBoundaryEvent> get onEnter => (_enter ??= GSignal<GPointerBoundaryEvent>());
  GSignal<GPointerBoundaryEvent> get onExit => (_exit ??= GSignal<GPointerBoundaryEvent>());

  void _dispatchEnter(GPointerBoundaryEvent event) {
    if (_disposed || !_input.enabled || _inside) return;
    _inside = true;
    _kind = event.kind;
    _x = event.x;
    _y = event.y;
    _enter?.emit(event);
  }

  void _dispatchExit(GPointerBoundaryEvent event) {
    if (_disposed || !_input.enabled || !_inside) return;
    _inside = false;
    _kind = event.kind;
    _x = event.x;
    _y = event.y;
    _exit?.emit(event);
  }

  bool _disposed = false;
  final GInput _input;

  final _sessions = <int, GPointerState>{};
  final panZoom = GPointerPanZoomState();

  double _x = 0.0;
  double _y = 0.0;
  double _deltaX = 0.0;
  double _deltaY = 0.0;
  GPointerDeviceKind _kind = GPointerDeviceKind.unknown;

  GCursor _cursor = GCursor.auto;
  GCursor? _hoverCursor;

  int? _primaryPointer;

  int _buttons = 0;
  int _pressedButtons = 0;
  int _releasedButtons = 0;

  double _scrollX = 0.0;
  double _scrollY = 0.0;

  GSignal<GPointerEvent>? _event;
  GSignal<GPointerEvent>? _down;
  GSignal<GPointerEvent>? _move;
  GSignal<GPointerEvent>? _up;
  GSignal<GPointerEvent>? _cancel;
  GSignal<GPointerEvent>? _hover;
  GSignal<GPointerEvent>? _scroll;
  GSignal<GPointerManager>? _reset;

  GSignal<GPointerPanZoomState>? _panZoomStart;
  GSignal<GPointerPanZoomState>? _panZoomUpdate;
  GSignal<GPointerPanZoomState>? _panZoomEnd;

  Iterable<GPointerState> get pointers => _sessions.values;

  int get pointerCount => _sessions.length;

  GPointerState? get primary {
    final id = _primaryPointer;
    return id == null ? null : _sessions[id];
  }

  GPointerState? pointer(int id) => _sessions[id];

  bool contains(int id) => _sessions.containsKey(id);

  double get x => _x;

  double get y => _y;

  /// Stage-space alias for [x].
  double get stageX => x;

  /// Stage-space alias for [y].
  double get stageY => y;

  double get deltaX => _deltaX;

  double get deltaY => _deltaY;

  GPointerDeviceKind get kind => _kind;

  /// Default cursor while the pointer is over this Stage.
  ///
  /// A hovered node cursor temporarily overrides this value without mutating
  /// it, so leaving that node restores the configured Stage cursor.
  GCursor get cursor => _cursor;
  set cursor(GCursor value) {
    if (identical(_cursor, value)) return;
    _cursor = value;
    _input._stage._syncCursor();
  }

  GCursor get _effectiveCursor => _hoverCursor ?? _cursor;

  void _setHoverCursor(GCursor? value) {
    if (identical(_hoverCursor, value)) return;
    _hoverCursor = value;
    _input._stage._syncCursor();
  }

  double get scrollX => _scrollX;

  double get scrollY => _scrollY;

  bool get didScroll => _scrollX != 0.0 || _scrollY != 0.0;

  int get buttons => _buttons;

  bool get isDown => _buttons != 0 || _hasTouchContact;

  bool get isPrimaryDown => (_buttons & kPrimaryButton) != 0;

  bool get isSecondaryDown => (_buttons & kSecondaryButton) != 0;

  bool get isMiddleDown => (_buttons & kTertiaryButton) != 0;

  bool wasButtonPressed(int button) => (_pressedButtons & button) != 0;

  bool wasButtonReleased(int button) => (_releasedButtons & button) != 0;

  bool get wasPrimaryPressed => wasButtonPressed(kPrimaryButton);

  bool get wasPrimaryReleased => wasButtonReleased(kPrimaryButton);

  bool get wasSecondaryPressed => wasButtonPressed(kSecondaryButton);

  bool get wasSecondaryReleased => wasButtonReleased(kSecondaryButton);

  bool get wasMiddlePressed => wasButtonPressed(kTertiaryButton);

  bool get wasMiddleReleased => wasButtonReleased(kTertiaryButton);

  // game-style
  bool get wasPressed => wasPrimaryPressed;

  bool get wasReleased => wasPrimaryReleased;

  bool get _hasTouchContact {
    for (final state in _sessions.values) {
      if (state.down &&
          (state.kind == GPointerDeviceKind.touch ||
              state.kind == GPointerDeviceKind.stylus ||
              state.kind == GPointerDeviceKind.invertedStylus)) {
        return true;
      }
    }
    return false;
  }

  GSignal<GPointerEvent> get onEvent => (_event ??= GSignal<GPointerEvent>());

  GSignal<GPointerEvent> get onDown => (_down ??= GSignal<GPointerEvent>());

  GSignal<GPointerEvent> get onMove => (_move ??= GSignal<GPointerEvent>());

  GSignal<GPointerEvent> get onUp => (_up ??= GSignal<GPointerEvent>());

  GSignal<GPointerEvent> get onCancel => (_cancel ??= GSignal<GPointerEvent>());

  GSignal<GPointerEvent> get onHover => (_hover ??= GSignal<GPointerEvent>());

  GSignal<GPointerEvent> get onScroll => (_scroll ??= GSignal<GPointerEvent>());

  /// Emitted after pointer state is cleared without ordinary up/cancel events,
  /// for example when Stage input is disabled.
  ///
  /// The manager itself is emitted to avoid allocating a reset event object.
  GSignal<GPointerManager> get onReset => (_reset ??= GSignal<GPointerManager>());

  GSignal<GPointerPanZoomState> get onPanZoomStart =>
      (_panZoomStart ??= GSignal<GPointerPanZoomState>());

  GSignal<GPointerPanZoomState> get onPanZoomUpdate =>
      (_panZoomUpdate ??= GSignal<GPointerPanZoomState>());

  GSignal<GPointerPanZoomState> get onPanZoomEnd =>
      (_panZoomEnd ??= GSignal<GPointerPanZoomState>());

  void _dispatch(GPointerEvent event) {
    if (_disposed || !_input.enabled) return;

    _updatePosition(event);

    switch (event.type) {
      case GPointerEventType.down:
        _handleDown(event);

      case GPointerEventType.move:
        _handleMove(event);

      case GPointerEventType.up:
        _handleUp(event);

      case GPointerEventType.cancel:
        _handleCancel(event);

      case GPointerEventType.hover:
        _hover?.emit(event);

      case GPointerEventType.scroll:
        _dispatchScroll(event);
        return;
    }

    _event?.emit(event);
    _input._stage.requestUpdate();
  }

  void _updatePosition(GPointerEvent event) {
    _kind = event.kind;
    _x = event.x;
    _y = event.y;
    _deltaX += event.deltaX;
    _deltaY += event.deltaY;
  }

  // down
  void _handleDown(GPointerEvent event) {
    final state = _sessions.putIfAbsent(
      event.pointer,
      () => GPointerState._(event.pointer),
    );
    _updateSession(state, event);
    if (!state.down) {
      state.down = true;
      state._pressedFrame = _input._eventFrame;
    }
    _primaryPointer = event.pointer;
    _updateButtons(event.buttons);
    _down?.emit(event);
  }

  // move
  void _handleMove(GPointerEvent event) {
    final state = _sessions[event.pointer];
    if (state != null) {
      _updateSession(state, event);
      _primaryPointer = event.pointer;
    }
    _updateButtons(event.buttons);
    _move?.emit(event);
  }

  // up
  void _handleUp(GPointerEvent event) {
    final state = _sessions[event.pointer];
    if (state != null) {
      _updateSession(state, event);
      state.down = false;
      state._releasedFrame = _input._eventFrame;
    }
    _primaryPointer = event.pointer;
    _updateButtons(event.buttons);
    _up?.emit(event);
  }

  // cancel
  void _handleCancel(GPointerEvent event) {
    final state = _sessions[event.pointer];
    if (state != null) {
      _updateSession(state, event);
      state.down = false;
      state._releasedFrame = _input._eventFrame;
    }
    _updateButtons(0);
    _cancel?.emit(event);
  }

  void _updateSession(GPointerState state, GPointerEvent event) {
    state.kind = event.kind;
    state.x = event.x;
    state.y = event.y;
    state.deltaX += event.deltaX;
    state.deltaY += event.deltaY;
    state.buttons = event.buttons;
  }

  // supports left, right, middle and additional ones (back and forward)
  // without changing api.
  void _updateButtons(int next) {
    final previous = _buttons;
    _pressedButtons |= next & ~previous;
    _releasedButtons |= previous & ~next;
    _buttons = next;
  }

  void _dispatchScroll(GPointerEvent event) {
    if (_disposed || !_input.enabled) return;

    _kind = event.kind;
    _x = event.x;
    _y = event.y;

    _accumulateScroll(event.scrollX, event.scrollY);

    _scroll?.emit(event);
    _event?.emit(event);

    _input._stage.requestUpdate();
  }

  void _accumulateScroll(double x, double y) {
    _scrollX += x;
    _scrollY += y;
  }

  void _beginPanZoom({
    required int pointer,
    required double x,
    required double y,
  }) {
    if (_disposed || !_input.enabled) return;

    panZoom
      ..active = true
      ..pointer = pointer
      ..x = x
      ..y = y
      ..panX = 0.0
      ..panY = 0.0
      ..panDeltaX = 0.0
      ..panDeltaY = 0.0
      ..scale = 1.0
      ..scaleDelta = 1.0
      ..rotation = 0.0
      ..rotationDelta = 0.0;

    _panZoomStart?.emit(panZoom);
    _input._stage.requestUpdate();
  }

  void _updatePanZoom({
    required int pointer,
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
    if (_disposed || !_input.enabled) return;

    final previousScale = panZoom.scale;
    final previousRotation = panZoom.rotation;

    panZoom
      ..active = true
      ..pointer = pointer
      ..x = x
      ..y = y
      ..panX = panX
      ..panY = panY
      ..panDeltaX += panDeltaX
      ..panDeltaY += panDeltaY
      ..scale = scale
      ..scaleDelta *= previousScale == 0.0 ? 1.0 : scale / previousScale
      ..rotation = rotation
      ..rotationDelta += rotation - previousRotation;

    // mmm, not sure if we should, unified scroll API
    // for macos magic mouse and trackpad.
    // TODO: remove if causes issues and remain consuming `panZoom`.
    // consume with `if(pointer.panZoom.active) pointer.scaleDelta`
    _accumulateScroll(panDeltaX, panDeltaY);
    final scrollEvent = GPointerEvent(
      type: GPointerEventType.scroll,
      pointer: pointer,
      kind: GPointerDeviceKind.trackpad,
      x: x,
      y: y,
      deltaX: 0.0,
      deltaY: 0.0,
      scrollX: panDeltaX,
      scrollY: panDeltaY,
      scrollSource: GPointerScrollSource.continuous,
      buttons: _buttons,
      timestamp: timestamp,
    );
    _scroll?.emit(scrollEvent);
    // --

    _panZoomUpdate?.emit(panZoom);
    _input._stage.requestUpdate();
  }

  void _endPanZoom() {
    if (_disposed || !_input.enabled || !panZoom.active) return;

    panZoom.active = false;

    _panZoomEnd?.emit(panZoom);
    _input._stage.requestUpdate();
  }

  void _resetFrameState() {
    _deltaX = 0.0;
    _deltaY = 0.0;

    _scrollX = 0.0;
    _scrollY = 0.0;

    _pressedButtons = 0;
    _releasedButtons = 0;

    panZoom
      ..panDeltaX = 0.0
      ..panDeltaY = 0.0
      ..scaleDelta = 1.0
      ..rotationDelta = 0.0;

    int? nextPrimary;
    _sessions.removeWhere((pointer, state) {
      state
        ..deltaX = 0.0
        ..deltaY = 0.0;
      if (state.down) {
        nextPrimary ??= pointer;
        return false;
      }
      return true;
    });
    _primaryPointer = nextPrimary;
  }

  void _clear({bool notify = true}) {
    _inside = false;
    _sessions.clear();
    _primaryPointer = null;
    _buttons = 0;
    _pressedButtons = 0;
    _releasedButtons = 0;
    _scrollX = 0.0;
    _scrollY = 0.0;
    _x = 0.0;
    _y = 0.0;
    _deltaX = 0.0;
    _deltaY = 0.0;
    _kind = GPointerDeviceKind.unknown;
    _setHoverCursor(null);
    panZoom._reset();
    if (notify) _reset?.emit(this);
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _clear(notify: false);

    _event?.dispose();
    _down?.dispose();
    _move?.dispose();
    _up?.dispose();
    _cancel?.dispose();
    _hover?.dispose();
    _scroll?.dispose();
    _reset?.dispose();
    _panZoomStart?.dispose();
    _panZoomUpdate?.dispose();
    _panZoomEnd?.dispose();
  }
}

// ================================
//   KEYBOARD
// ================================

// maybe expose the "is" getters inside the Enum.
enum GKeyEventType { down, repeat, up }

final class GKeyEvent {
  GKeyEvent({
    required this.type,
    required this.logicalKey,
    required this.physicalKey,
    required this.timestamp,
    required this.character,
  });

  final GKeyEventType type;
  final LogicalKeyboardKey logicalKey;
  final PhysicalKeyboardKey physicalKey;
  final Duration timestamp;
  final String? character;

  bool get isDown => type == GKeyEventType.down;

  bool get isUp => type == GKeyEventType.up;

  bool get isRepeat => type == GKeyEventType.repeat;

  @override
  String toString() {
    final out = GDebugString('GKeyEvent')
      ..value(type.name)
      ..field('key', logicalKey.debugName ?? logicalKey.keyLabel);
    if (character case final character? when character.isNotEmpty) {
      out.field('char', '"$character"');
    }
    return out.toString();
  }
}

typedef GKey = LogicalKeyboardKey;

final class GKeyboardManager implements _GDisposable {
  GKeyboardManager._(this._input);

  final GInput _input;
  final _downKeys = <GKey>{};
  final _pressedFrames = <GKey, int>{};
  final _releasedFrames = <GKey, int>{};

  GSignal<GKeyEvent>? _repeat;
  GSignal<GKeyEvent>? _event;
  GSignal<GKeyEvent>? _down;
  GSignal<GKeyEvent>? _up;
  GSignal<GKeyboardManager>? _reset;

  bool _disposed = false;

  GSignal<GKeyEvent> get onRepeat => (_repeat ??= GSignal<GKeyEvent>());

  GSignal<GKeyEvent> get onEvent => (_event ??= GSignal<GKeyEvent>());

  GSignal<GKeyEvent> get onDown => (_down ??= GSignal<GKeyEvent>());

  GSignal<GKeyEvent> get onUp => (_up ??= GSignal<GKeyEvent>());

  /// Emitted after held-key state is cleared without ordinary key-up events,
  /// for example when GraphXView loses Flutter focus or Stage input is disabled.
  ///
  /// The manager itself is emitted to avoid allocating a reset event object.
  GSignal<GKeyboardManager> get onReset => (_reset ??= GSignal<GKeyboardManager>());

  Set<GKey> get downKeys => Set.unmodifiable(_downKeys);

  bool isDown(GKey key) => _downKeys.contains(key);

  bool wasPressed(GKey key) => _pressedFrames[key] == _input._stage.frame;

  bool wasReleased(GKey key) => _releasedFrames[key] == _input._stage.frame;

  bool get shift => isDown(GKey.shiftLeft) || isDown(GKey.shiftRight);

  bool get control => isDown(GKey.controlLeft) || isDown(GKey.controlRight);

  bool get alt => isDown(GKey.altLeft) || isDown(GKey.altRight);

  bool get meta => isDown(GKey.metaLeft) || isDown(GKey.metaRight);

  void _dispatch(GKeyEvent event) {
    if (_disposed || !_input.enabled) return;
    switch (event.type) {
      case GKeyEventType.down:
        final added = _downKeys.add(event.logicalKey);
        if (added) {
          _pressedFrames[event.logicalKey] = _input._eventFrame;
          _down?.emit(event);
        } else {
          _repeat?.emit(event);
        }
      case GKeyEventType.repeat:
        _downKeys.add(event.logicalKey);
        _repeat?.emit(event);
      case GKeyEventType.up:
        _downKeys.remove(event.logicalKey);
        _releasedFrames[event.logicalKey] = _input._eventFrame;
        _up?.emit(event);
    }
    _event?.emit(event);
  }

  void _clear({bool notify = true}) {
    _downKeys.clear();
    _pressedFrames.clear();
    _releasedFrames.clear();
    if (notify) _reset?.emit(this);
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clear(notify: false);
    _repeat?.dispose();
    _event?.dispose();
    _down?.dispose();
    _up?.dispose();
    _reset?.dispose();
  }
}

final class GInput implements _GDisposable {
  final GStage _stage;
  late final GPointerManager pointer;
  late final GKeyboardManager keyboard;

  bool _enabled;
  bool _disposed = false;

  GInput._(this._stage, {required this._enabled}) {
    pointer = GPointerManager._(this);
    keyboard = GKeyboardManager._(this);
  }

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      pointer._clear();
      keyboard._clear();
    }
  }

  // events received "in between" frames A/B, belongs to next frame (B)
  int get _eventFrame => _stage.frame + 1;

  void _beginFrame() {}

  void _endFrame() {
    pointer._resetFrameState();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    pointer.dispose();
    keyboard.dispose();
  }

  @override
  bool get isDisposed => _disposed;
}
