// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Stable semantic input identity, independent from the device that produced it.
final class GAction {
  const GAction(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is GAction && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GAction($id)';
}

/// Conventional actions shared by keyboard, TV remotes, gamepads and semantics.
abstract final class GActions {
  static const activate = GAction('activate');
  static const back = GAction('back');
  static const focusNext = GAction('focusNext');
  static const focusPrevious = GAction('focusPrevious');
  static const focusLeft = GAction('focusLeft');
  static const focusRight = GAction('focusRight');
  static const focusUp = GAction('focusUp');
  static const focusDown = GAction('focusDown');
}

enum GActionPhase { pressed, repeated, released }

enum GActionSource { keyboard, remote, gamepad, accessibility, synthetic }

/// One semantic input event routed through the currently focused GraphX path.
final class GActionEvent {
  GActionEvent({
    required this.action,
    required this.phase,
    required this.source,
    required this.value,
    required this.target,
    this.keyEvent,
  });

  final GAction action;
  final GActionPhase phase;
  final GActionSource source;
  final double value;
  final GNode? target;
  final GKeyEvent? keyEvent;

  GNode? _currentTarget;
  bool handled = false;

  GNode? get currentTarget => _currentTarget;
  bool get isPressed => phase == GActionPhase.pressed;
  bool get isRepeat => phase == GActionPhase.repeated;
  bool get isReleased => phase == GActionPhase.released;

  void handle() => handled = true;
}

/// A logical-key shortcut with exact modifier matching.
final class GShortcut {
  const GShortcut(
    this.key, {
    this.shift = false,
    this.control = false,
    this.alt = false,
    this.meta = false,
  });

  final GKey key;
  final bool shift;
  final bool control;
  final bool alt;
  final bool meta;

  factory GShortcut._fromEvent(GKeyEvent event, GKeyboardManager keyboard) {
    return GShortcut(
      event.logicalKey,
      shift: keyboard.shift,
      control: keyboard.control,
      alt: keyboard.alt,
      meta: keyboard.meta,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GShortcut &&
        other.key == key &&
        other.shift == shift &&
        other.control == control &&
        other.alt == alt &&
        other.meta == meta;
  }

  @override
  int get hashCode => Object.hash(key, shift, control, alt, meta);
}

/// Semantic action facade for one Stage.
///
/// Keyboard bindings are only one producer. Remote/gamepad/accessibility
/// adapters can call [dispatch] directly without pretending to be keyboards.
final class GActionInput {
  GActionInput._(this._focus);

  final GFocusManager _focus;
  Map<GShortcut, GAction>? _bindings;
  Map<GAction, GSignal<GActionEvent>>? _signals;
  GSignal<GActionEvent>? _any;

  GSignalView<GActionEvent> get onAny => (_any ??= GSignal<GActionEvent>()).view;

  GSignalView<GActionEvent> on(GAction action) {
    final signals = _signals ??= <GAction, GSignal<GActionEvent>>{};
    return (signals[action] ??= GSignal<GActionEvent>()).view;
  }

  GActionInput bind(GShortcut shortcut, GAction action) {
    (_bindings ??= <GShortcut, GAction>{})[shortcut] = action;
    return this;
  }

  bool unbind(GShortcut shortcut) => _bindings?.remove(shortcut) != null;

  void clearBindings() => _bindings?.clear();

  /// Sends one already-normalized semantic action through the focus route.
  bool dispatch(
    GAction action, {
    GActionPhase phase = GActionPhase.pressed,
    GActionSource source = GActionSource.synthetic,
    double value = 1.0,
  }) {
    return _focus._dispatchAction(
      GActionEvent(
        action: action,
        phase: phase,
        source: source,
        value: value,
        target: _focus.focusedNode,
      ),
    );
  }

  bool _dispatchKey(GKeyEvent event) {
    final keyboard = _focus._stage.input.keyboard;
    final shortcut = GShortcut._fromEvent(event, keyboard);
    final action = _bindings?[shortcut] ?? _defaultAction(event, keyboard);
    if (action == null) return false;

    final phase = switch (event.type) {
      GKeyEventType.down => GActionPhase.pressed,
      GKeyEventType.repeat => GActionPhase.repeated,
      GKeyEventType.up => GActionPhase.released,
    };
    return _focus._dispatchAction(
      GActionEvent(
        action: action,
        phase: phase,
        source: GActionSource.keyboard,
        value: phase == GActionPhase.released ? 0.0 : 1.0,
        target: _focus.focusedNode,
        keyEvent: event,
      ),
    );
  }

  GAction? _defaultAction(GKeyEvent event, GKeyboardManager keyboard) {
    final key = event.logicalKey;
    if (key == GKey.tab) {
      return keyboard.shift ? GActions.focusPrevious : GActions.focusNext;
    }
    if (key == GKey.arrowLeft) return GActions.focusLeft;
    if (key == GKey.arrowRight) return GActions.focusRight;
    if (key == GKey.arrowUp) return GActions.focusUp;
    if (key == GKey.arrowDown) return GActions.focusDown;
    if (key == GKey.enter ||
        key == GKey.numpadEnter ||
        key == GKey.space ||
        key == GKey.select ||
        key == GKey.gameButtonA) {
      return GActions.activate;
    }
    if (key == GKey.escape || key == GKey.goBack || key == GKey.gameButtonB) {
      return GActions.back;
    }
    return null;
  }

  void _emitGlobal(GActionEvent event) {
    _signals?[event.action]?.emit(event);
    _any?.emit(event);
  }

  void _dispose() {
    _any?.dispose();
    final signals = _signals;
    if (signals != null) {
      for (final signal in signals.values) {
        signal.dispose();
      }
      signals.clear();
    }
    _bindings?.clear();
  }
}

enum GFocusDirection { left, right, up, down }

/// What happens when traversal reaches the logical edge of a GraphX scene.
enum GFocusEdgeBehavior {
  /// Delegate beyond GraphXView to the surrounding Flutter traversal policy.
  parent,

  /// Keep focus at the current edge.
  stop,

  /// Continue at the opposite edge of the GraphX scene.
  wrap,
}

/// Lazily allocated advanced focus policy for one [GNode].
///
/// Most code only needs `node.focusable`, `node.requestFocus()` and
/// `node.onAction`. Access this object for explicit neighbors or focus behavior.
final class GNodeFocus {
  GNodeFocus._(this._node);

  final GNode _node;

  bool? _focusableOverride;
  bool _portalAvailable = false;
  bool _skipTraversal = false;
  bool _focusOnPointer = true;
  bool _registered = false;
  bool _disposed = false;

  /// Optional explicit sequential/directional neighbors.
  GNode? next;
  GNode? previous;
  GNode? left;
  GNode? right;
  GNode? up;
  GNode? down;

  GSignal<bool>? _changed;
  GSignal<bool>? _withinChanged;
  GSignal<GActionEvent>? _action;
  GSignalSubscription? _pointerFocusSubscription;

  bool get focusable => _effectiveFocusable;

  bool get skipTraversal => _skipTraversal;
  set skipTraversal(bool value) {
    if (_skipTraversal == value) return;
    _skipTraversal = value;
    _syncNodeFocusRegistration(_node, this);
  }

  /// Whether a pointer press directly targeting this node requests focus.
  bool get focusOnPointer => _focusOnPointer;
  set focusOnPointer(bool value) {
    if (_focusOnPointer == value) return;
    _focusOnPointer = value;
    _syncPointerFocus(this);
  }

  GSignalView<bool> get onChanged => (_changed ??= GSignal<bool>()).view;
  GSignalView<bool> get onWithinChanged => (_withinChanged ??= GSignal<bool>()).view;
  GSignalView<GActionEvent> get onAction => (_action ??= GSignal<GActionEvent>()).view;

  bool get _effectiveFocusable => _focusableOverride ?? _portalAvailable;

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    _pointerFocusSubscription?.cancel();
    _pointerFocusSubscription = null;
    _changed?.dispose();
    _withinChanged?.dispose();
    _action?.dispose();
    next = previous = left = right = up = down = null;
  }
}

final Expando<GNodeFocus> _gNodeFocus = Expando<GNodeFocus>('GNode.focus');
final Expando<GFocusManager> _gStageFocus = Expando<GFocusManager>(
  'GStage.focus',
);
final Expando<_GFocusHostBridge> _gFocusHosts = Expando<_GFocusHostBridge>(
  'GStage.focusHost',
);

GNodeFocus? _maybeNodeFocus(GNode node) => _gNodeFocus[node];

GNodeFocus _ensureNodeFocus(GNode node) {
  if (node.isDisposed) {
    throw StateError('Cannot access focus state on a disposed node.');
  }
  return _gNodeFocus[node] ??= GNodeFocus._(node);
}

extension GNodeFocusApi on GNode {
  /// Whether this node can become the logical GraphX focus target.
  ///
  /// Portals become focusable automatically while their Flutter subtree has
  /// traversable descendants. Assigning this property overrides that default.
  bool get focusable => _maybeNodeFocus(this)?._effectiveFocusable ?? false;
  set focusable(bool value) {
    final state = value ? _ensureNodeFocus(this) : _maybeNodeFocus(this);
    if (state == null || state._focusableOverride == value) return;
    state._focusableOverride = value;
    _syncNodeFocusRegistration(this, state);
    _syncPointerFocus(state);
    final stage = _stage;
    final manager = stage == null ? null : _gStageFocus[stage];
    if (!value && identical(manager?.focusedNode, this)) manager!.clear();
  }

  bool get hasFocus {
    final stage = _stage;
    return stage != null && identical(_gStageFocus[stage]?.focusedNode, this);
  }

  bool get hasFocusWithin {
    final stage = _stage;
    if (stage == null) return false;
    var current = _gStageFocus[stage]?.focusedNode;
    while (current != null) {
      if (identical(current, this)) return true;
      current = current._parent;
    }
    return false;
  }

  /// Requests logical focus. Returns false when the node is currently ineligible.
  bool requestFocus() {
    final stage = _stage;
    return stage != null && stage.focus.requestFocus(this);
  }

  void clearFocus() {
    final stage = _stage;
    final manager = stage == null ? null : _gStageFocus[stage];
    if (identical(manager?.focusedNode, this)) manager!.clear();
  }

  /// Advanced focus configuration, allocated only when accessed.
  GNodeFocus get focus => _ensureNodeFocus(this);

  GSignalView<bool> get onFocusChanged => _ensureNodeFocus(this).onChanged;
  GSignalView<bool> get onFocusWithinChanged => _ensureNodeFocus(this).onWithinChanged;
  GSignalView<GActionEvent> get onAction => _ensureNodeFocus(this).onAction;
}

extension GStageFocusApi on GStage {
  GFocusManager get focus {
    if (isDisposed) throw StateError('Cannot access focus on a disposed Stage.');
    return _gStageFocus[this] ??= GFocusManager._(this);
  }

  GActionInput get actions => focus.actions;
}

extension GInputActionApi on GInput {
  GActionInput get actions => _stage.focus.actions;
}

abstract interface class _GFocusHostBridge {
  void requestEngineFocus();
  void enterPortal(GPortal<dynamic> portal, bool forward);
  void leaveSequential(bool forward);
  void leaveDirection(GFocusDirection direction);
  void traversalChanged();
}

void _bindStageFocusHost(GStage stage, _GFocusHostBridge host) {
  _gFocusHosts[stage] = host;
  _gStageFocus[stage]?._bindHost(host);
}

void _unbindStageFocusHost(GStage stage, _GFocusHostBridge host) {
  if (identical(_gFocusHosts[stage], host)) _gFocusHosts[stage] = null;
  _gStageFocus[stage]?._unbindHost(host);
}

/// Stage-local logical focus owner.
///
/// This is intentionally not a second node tree. The retained GraphX scene is
/// the focus tree; this manager only owns the current target and cold-path
/// traversal/routing policy.
final class GFocusManager {
  GFocusManager._(this._stage) {
    actions = GActionInput._(this);
    _host = _gFocusHosts[_stage];
  }

  final GStage _stage;
  late final GActionInput actions;

  GNode? _focusedNode;
  _GFocusHostBridge? _host;
  int _traversableCount = 0;

  GFocusEdgeBehavior edgeBehavior = GFocusEdgeBehavior.parent;

  final GBounds _sourceBounds = GBounds.empty();
  final GBounds _candidateBounds = GBounds.empty();
  final GBounds _projectedLocalBounds = GBounds.empty();
  final GPoint _projectedPoint = GPoint();

  GNode? get focusedNode => _focusedNode;
  bool get hasFocus => _focusedNode != null;
  bool get hasFocusableNodes => _traversableCount > 0;

  bool requestFocus(GNode node) {
    if (!_isEligible(node, traversal: false)) return false;
    _setFocused(node, requestHost: true, portalForward: true);
    return true;
  }

  void clear() => _setFocused(null, requestHost: false);

  bool next() => _moveSequential(true);
  bool previous() => _moveSequential(false);

  bool move(GFocusDirection direction) {
    final current = _focusedNode;
    if (current == null) {
      final first = _firstEligible();
      if (first == null) return _handleDirectionalEdge(direction);
      _setFocused(first, requestHost: true, portalForward: true);
      return true;
    }

    final configured = switch (direction) {
      GFocusDirection.left => _maybeNodeFocus(current)?.left,
      GFocusDirection.right => _maybeNodeFocus(current)?.right,
      GFocusDirection.up => _maybeNodeFocus(current)?.up,
      GFocusDirection.down => _maybeNodeFocus(current)?.down,
    };
    if (configured != null && _isEligible(configured, traversal: true)) {
      _setFocused(configured, requestHost: true, portalForward: true);
      return true;
    }

    final candidate = _findDirectional(current, direction);
    if (candidate != null) {
      _setFocused(candidate, requestHost: true, portalForward: true);
      return true;
    }
    return _handleDirectionalEdge(direction);
  }

  bool _moveSequential(bool forward) {
    final current = _focusedNode;
    final configured = current == null
        ? null
        : forward
        ? _maybeNodeFocus(current)?.next
        : _maybeNodeFocus(current)?.previous;
    if (configured != null && _isEligible(configured, traversal: true)) {
      _setFocused(configured, requestHost: true, portalForward: forward);
      return true;
    }

    final candidate = current == null
        ? (forward ? _firstEligible() : _lastEligible())
        : _findSequential(current, forward);
    if (candidate != null) {
      _setFocused(candidate, requestHost: true, portalForward: forward);
      return true;
    }

    switch (edgeBehavior) {
      case GFocusEdgeBehavior.stop:
        return false;
      case GFocusEdgeBehavior.wrap:
        final wrapped = forward ? _firstEligible() : _lastEligible();
        if (wrapped == null || identical(wrapped, current)) return false;
        _setFocused(wrapped, requestHost: true, portalForward: forward);
        return true;
      case GFocusEdgeBehavior.parent:
        final host = _host;
        if (host == null) return false;
        host.leaveSequential(forward);
        return true;
    }
  }

  bool _handleDirectionalEdge(GFocusDirection direction) {
    switch (edgeBehavior) {
      case GFocusEdgeBehavior.stop:
        return false;
      case GFocusEdgeBehavior.wrap:
        final wrapped = _findDirectionalWrap(direction);
        if (wrapped == null || identical(wrapped, _focusedNode)) return false;
        _setFocused(wrapped, requestHost: true, portalForward: true);
        return true;
      case GFocusEdgeBehavior.parent:
        final host = _host;
        if (host == null) return false;
        host.leaveDirection(direction);
        return true;
    }
  }

  bool _dispatchAction(GActionEvent event) {
    GNode? current = _focusedNode ?? _stage.root;
    while (current != null) {
      final signal = _maybeNodeFocus(current)?._action;
      if (signal != null) {
        event._currentTarget = current;
        signal.emit(event);
        if (event.handled) return true;
      }
      current = current._parent;
    }

    event._currentTarget = null;
    actions._emitGlobal(event);
    if (event.handled) return true;
    if (event.phase == GActionPhase.released) return false;

    if (event.action == GActions.focusNext) return next();
    if (event.action == GActions.focusPrevious) return previous();
    if (event.action == GActions.focusLeft) return move(GFocusDirection.left);
    if (event.action == GActions.focusRight) return move(GFocusDirection.right);
    if (event.action == GActions.focusUp) return move(GFocusDirection.up);
    if (event.action == GActions.focusDown) return move(GFocusDirection.down);
    return false;
  }

  bool _isEligible(GNode node, {required bool traversal}) {
    if (node.isDisposed || !identical(node._stage, _stage)) return false;
    final state = _maybeNodeFocus(node);
    if (state == null || !state._effectiveFocusable) return false;
    if (traversal && state._skipTraversal) return false;

    GNode? current = node;
    while (current != null) {
      if (!current._visible || !current._active) return false;
      current = current._parent;
    }

    final root = _stage.root;
    if (_hasInteractionMapperToAncestor(node, root) &&
        !_interactionLocalToAncestorInto(
          node,
          root,
          0.0,
          0.0,
          _projectedPoint,
        )) {
      return false;
    }
    return true;
  }

  GNode? _firstEligible() {
    GNode? found;
    bool visit(GNode node) {
      if (_isEligible(node, traversal: true)) {
        found = node;
        return true;
      }
      final children = node._children;
      if (children == null) return false;
      for (var i = 0; i < children.length; ++i) {
        if (visit(children[i])) return true;
      }
      return false;
    }

    visit(_stage.root);
    return found;
  }

  GNode? _lastEligible() {
    GNode? found;
    void visit(GNode node) {
      if (_isEligible(node, traversal: true)) found = node;
      final children = node._children;
      if (children == null) return;
      for (var i = 0; i < children.length; ++i) {
        visit(children[i]);
      }
    }

    visit(_stage.root);
    return found;
  }

  GNode? _findSequential(GNode current, bool forward) {
    GNode? result;
    GNode? previous;
    var passedCurrent = false;

    bool visit(GNode node) {
      if (_isEligible(node, traversal: true)) {
        if (forward) {
          if (passedCurrent) {
            result = node;
            return true;
          }
          if (identical(node, current)) passedCurrent = true;
        } else {
          if (identical(node, current)) {
            result = previous;
            return true;
          }
          previous = node;
        }
      } else if (identical(node, current)) {
        passedCurrent = true;
        if (!forward) {
          result = previous;
          return true;
        }
      }

      final children = node._children;
      if (children == null) return false;
      for (var i = 0; i < children.length; ++i) {
        if (visit(children[i])) return true;
      }
      return false;
    }

    visit(_stage.root);
    return result;
  }

  GNode? _findDirectional(GNode current, GFocusDirection direction) {
    _boundsFor(current, _sourceBounds);
    final sx = (_sourceBounds.x1 + _sourceBounds.x2) * 0.5;
    final sy = (_sourceBounds.y1 + _sourceBounds.y2) * 0.5;

    GNode? best;
    var bestScore = double.infinity;

    void visit(GNode node) {
      if (!identical(node, current) && _isEligible(node, traversal: true)) {
        _boundsFor(node, _candidateBounds);
        final cx = (_candidateBounds.x1 + _candidateBounds.x2) * 0.5;
        final cy = (_candidateBounds.y1 + _candidateBounds.y2) * 0.5;
        final dx = cx - sx;
        final dy = cy - sy;

        final primary = switch (direction) {
          GFocusDirection.left => -dx,
          GFocusDirection.right => dx,
          GFocusDirection.up => -dy,
          GFocusDirection.down => dy,
        };
        if (primary > 1e-9) {
          final secondary = switch (direction) {
            GFocusDirection.left || GFocusDirection.right => dy.abs(),
            GFocusDirection.up || GFocusDirection.down => dx.abs(),
          };
          final overlapsBeam = switch (direction) {
            GFocusDirection.left || GFocusDirection.right =>
              _candidateBounds.y1 < _sourceBounds.y2 && _candidateBounds.y2 > _sourceBounds.y1,
            GFocusDirection.up || GFocusDirection.down =>
              _candidateBounds.x1 < _sourceBounds.x2 && _candidateBounds.x2 > _sourceBounds.x1,
          };
          var score = primary * primary + secondary * secondary * 4.0;
          if (overlapsBeam) score *= 0.25;
          if (score < bestScore) {
            bestScore = score;
            best = node;
          }
        }
      }

      final children = node._children;
      if (children == null) return;
      for (var i = 0; i < children.length; ++i) {
        visit(children[i]);
      }
    }

    visit(_stage.root);
    return best;
  }

  GNode? _findDirectionalWrap(GFocusDirection direction) {
    GNode? best;
    var bestPrimary = switch (direction) {
      GFocusDirection.left || GFocusDirection.up => double.negativeInfinity,
      GFocusDirection.right || GFocusDirection.down => double.infinity,
    };

    void visit(GNode node) {
      if (_isEligible(node, traversal: true)) {
        _boundsFor(node, _candidateBounds);
        final cx = (_candidateBounds.x1 + _candidateBounds.x2) * 0.5;
        final cy = (_candidateBounds.y1 + _candidateBounds.y2) * 0.5;
        final primary = switch (direction) {
          GFocusDirection.left || GFocusDirection.right => cx,
          GFocusDirection.up || GFocusDirection.down => cy,
        };
        final better = switch (direction) {
          GFocusDirection.left || GFocusDirection.up => primary > bestPrimary,
          GFocusDirection.right || GFocusDirection.down => primary < bestPrimary,
        };
        if (better) {
          bestPrimary = primary;
          best = node;
        }
      }
      final children = node._children;
      if (children == null) return;
      for (var i = 0; i < children.length; ++i) {
        visit(children[i]);
      }
    }

    visit(_stage.root);
    return best;
  }

  void _boundsFor(GNode node, GBounds out) {
    final root = _stage.root;
    if (!_hasInteractionMapperToAncestor(node, root)) {
      node.getBounds(root, out);
      if (!out.isEmpty) return;
      node._ensureWorldTransform();
      final matrix = node._worldMatrix!;
      out.set(matrix.tx, matrix.ty, matrix.tx, matrix.ty);
      return;
    }

    node.getLocalBounds(_projectedLocalBounds);
    final local = _projectedLocalBounds;
    out.setEmpty();
    if (local.isEmpty) {
      if (_interactionLocalToAncestorInto(
        node,
        root,
        0.0,
        0.0,
        _projectedPoint,
      )) {
        out.includePoint(_projectedPoint.x, _projectedPoint.y);
      }
      return;
    }

    if (!_includeProjectedPoint(node, root, local.x1, local.y1, out) ||
        !_includeProjectedPoint(node, root, local.x2, local.y1, out) ||
        !_includeProjectedPoint(node, root, local.x1, local.y2, out) ||
        !_includeProjectedPoint(node, root, local.x2, local.y2, out)) {
      out.setEmpty();
    }
  }

  bool _includeProjectedPoint(
    GNode node,
    GNode root,
    double x,
    double y,
    GBounds out,
  ) {
    if (!_interactionLocalToAncestorInto(node, root, x, y, _projectedPoint)) {
      return false;
    }
    out.includePoint(_projectedPoint.x, _projectedPoint.y);
    return true;
  }

  void _setFocused(
    GNode? next, {
    required bool requestHost,
    bool portalForward = true,
  }) {
    final previous = _focusedNode;
    if (identical(previous, next)) {
      if (requestHost && next != null) _requestHostFor(next, portalForward);
      return;
    }

    final previousPath = _focusPath(previous);
    final nextPath = _focusPath(next);

    _focusedNode = next;
    if (previous != null) _maybeNodeFocus(previous)?._changed?.emit(false);
    for (final node in previousPath) {
      if (!nextPath.contains(node)) {
        _maybeNodeFocus(node)?._withinChanged?.emit(false);
      }
    }

    if (next != null) _maybeNodeFocus(next)?._changed?.emit(true);
    for (final node in nextPath) {
      if (!previousPath.contains(node)) {
        _maybeNodeFocus(node)?._withinChanged?.emit(true);
      }
    }

    if (requestHost && next != null) _requestHostFor(next, portalForward);
  }

  Set<GNode> _focusPath(GNode? node) {
    final path = <GNode>{};
    while (node != null) {
      path.add(node);
      node = node._parent;
    }
    return path;
  }

  void _reparented(GNode subtree, GNode oldParent, GNode newParent) {
    final focused = _focusedNode;
    if (focused == null || !_isDescendantOrSelf(focused, subtree)) return;

    final oldPath = <GNode>{};
    GNode? current = focused;
    while (current != null) {
      oldPath.add(current);
      current = identical(current, subtree) ? oldParent : current._parent;
    }
    final newPath = _focusPath(focused);

    if (!_isEligible(focused, traversal: false)) {
      _focusedNode = null;
      _maybeNodeFocus(focused)?._changed?.emit(false);
      for (final node in oldPath) {
        _maybeNodeFocus(node)?._withinChanged?.emit(false);
      }
      return;
    }

    for (final node in oldPath) {
      if (!newPath.contains(node)) {
        _maybeNodeFocus(node)?._withinChanged?.emit(false);
      }
    }
    for (final node in newPath) {
      if (!oldPath.contains(node)) {
        _maybeNodeFocus(node)?._withinChanged?.emit(true);
      }
    }
  }

  void _requestHostFor(GNode node, bool portalForward) {
    final host = _host;
    if (host == null) return;
    if (node is GPortal<dynamic> && _maybeNodeFocus(node)?._portalAvailable == true) {
      host.enterPortal(node, portalForward);
    } else {
      host.requestEngineFocus();
    }
  }

  void _register(GNodeFocus state) {
    if (state._registered) return;
    state._registered = true;
    _traversableCount++;
    _host?.traversalChanged();
  }

  void _unregister(GNodeFocus state) {
    if (!state._registered) return;
    state._registered = false;
    _traversableCount--;
    assert(_traversableCount >= 0);
    _host?.traversalChanged();
  }

  void _repairIfNeeded(GNode changedAncestor) {
    final focused = _focusedNode;
    if (focused == null || !_isDescendantOrSelf(focused, changedAncestor)) return;
    if (!_isEligible(focused, traversal: false)) clear();
  }

  void _bindHost(_GFocusHostBridge host) {
    _host = host;
    host.traversalChanged();
  }

  void _unbindHost(_GFocusHostBridge host) {
    if (identical(_host, host)) _host = null;
  }

  void _hostBlurred() {
    if (_focusedNode != null) _setFocused(null, requestHost: false);
  }

  void _portalFocused(GPortal<dynamic> portal) {
    if (!_isEligible(portal, traversal: false)) return;
    _setFocused(portal, requestHost: false);
  }

  void _portalBlurred(GPortal<dynamic> portal) {
    if (identical(_focusedNode, portal)) {
      _setFocused(null, requestHost: false);
    }
  }

  void _portalEntryFailed(GPortal<dynamic> portal, bool forward) {
    if (!identical(_focusedNode, portal)) return;
    if (!_moveSequential(forward)) clear();
  }

  void _dispose() {
    _setFocused(null, requestHost: false);
    actions._dispose();
    _host = null;
    _traversableCount = 0;
  }
}

bool _isDescendantOrSelf(GNode node, GNode ancestor) {
  GNode? current = node;
  while (current != null) {
    if (identical(current, ancestor)) return true;
    current = current._parent;
  }
  return false;
}

void _syncPointerFocus(GNodeFocus state) {
  final node = state._node;
  final shouldListen =
      !state._disposed &&
      state._focusOnPointer &&
      state._effectiveFocusable &&
      node is! GPortal<dynamic>;
  final subscription = state._pointerFocusSubscription;
  if (shouldListen == (subscription != null && subscription.isActive)) return;

  subscription?.cancel();
  state._pointerFocusSubscription = null;
  if (!shouldListen) return;
  state._pointerFocusSubscription = node.pointer.onDown.add((event) {
    if (identical(event.target, node)) node.requestFocus();
  });
}

void _syncNodeFocusRegistration(GNode node, GNodeFocus state) {
  final stage = node._stage;
  if (stage == null) {
    if (state._registered) {
      throw StateError('Detached focus state remained registered.');
    }
    _syncPointerFocus(state);
    return;
  }
  final shouldRegister = state._effectiveFocusable && !state._skipTraversal;
  if (shouldRegister) {
    stage.focus._register(state);
  } else {
    _gStageFocus[stage]?._unregister(state);
  }
  _syncPointerFocus(state);
}

void _focusNodeAttached(GNode node, GStage stage) {
  final state = _maybeNodeFocus(node);
  if (state == null) return;
  _syncNodeFocusRegistration(node, state);
}

void _focusNodeDetached(GNode node, GStage stage) {
  final state = _maybeNodeFocus(node);
  if (state == null) return;
  final manager = _gStageFocus[stage];
  manager?._unregister(state);
  if (identical(manager?.focusedNode, node)) manager!.clear();
}

void _focusNodeReparented(GNode subtree, GNode oldParent, GNode newParent) {
  final stage = subtree._stage;
  if (stage == null) return;
  _gStageFocus[stage]?._reparented(subtree, oldParent, newParent);
}

void _focusNodeStateChanged(GNode node) {
  final stage = node._stage;
  if (stage == null) return;
  _gStageFocus[stage]?._repairIfNeeded(node);
}

void _disposeNodeFocus(GNode node) {
  final state = _maybeNodeFocus(node);
  if (state == null) return;
  final stage = node._stage;
  if (stage != null) {
    final manager = _gStageFocus[stage];
    manager?._unregister(state);
    if (identical(manager?.focusedNode, node)) manager!.clear();
  }
  state._dispose();
  _gNodeFocus[node] = null;
}

void _disposeStageFocus(GStage stage) {
  _gStageFocus[stage]?._dispose();
  _gStageFocus[stage] = null;
  _gFocusHosts[stage] = null;
}

void _setPortalFocusAvailable(GPortal<dynamic> portal, bool available) {
  if (portal.isDisposed) return;
  final state = _ensureNodeFocus(portal);
  if (state._portalAvailable == available) return;
  state._portalAvailable = available;
  _syncNodeFocusRegistration(portal, state);
  if (!state._effectiveFocusable && portal.hasFocus) portal.clearFocus();
}
