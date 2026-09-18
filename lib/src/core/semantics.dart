part of 'package:graphx/graphx.dart';

/// Platform-neutral semantic role for one retained [GNode].
///
/// This intentionally covers only the roles GraphX controls need today.
/// Platform bridges may map simple roles to native semantic flags and richer
/// roles to the platform's role model.
enum GSemanticsRole {
  generic,
  text,
  button,
  image,
  toggle,
  checkbox,
  radio,
  slider,
  menu,
  menuItem,
}

/// Standard accessibility actions that do not already have a conventional
/// identity in [GActions]. They still route as ordinary [GAction]s.
abstract final class GSemanticsActions {
  static const increment = GAction('increment');
  static const decrement = GAction('decrement');
  static const dismiss = GAction('dismiss');
}

/// Lazily allocated semantic state for one [GNode].
///
/// Accessing this object alone does not register the node in the semantic
/// subtree. Registration starts only after at least one semantic property or
/// semantic action differs from its default value.
final class GNodeSemantics {
  GNodeSemantics._(this._node);

  final GNode _node;

  String? _label;
  String? _value;
  String? _increasedValue;
  String? _decreasedValue;
  String? _hint;
  GSemanticsRole _role = GSemanticsRole.generic;
  bool? _enabled;
  bool? _selected;
  bool? _checked;
  bool? _toggled;
  bool _mergeDescendants = false;
  bool _excludeDescendants = false;
  Set<GAction>? _actions;

  String? get label => _label;
  set label(String? value) {
    if (_label == value) return;
    _label = value;
    _changed();
  }

  String? get value => _value;
  set value(String? value) {
    if (_value == value) return;
    _value = value;
    _changed();
  }

  /// Value announced for the result of an accessibility increment action.
  String? get increasedValue => _increasedValue;
  set increasedValue(String? value) {
    if (_increasedValue == value) return;
    _increasedValue = value;
    _changed();
  }

  /// Value announced for the result of an accessibility decrement action.
  String? get decreasedValue => _decreasedValue;
  set decreasedValue(String? value) {
    if (_decreasedValue == value) return;
    _decreasedValue = value;
    _changed();
  }

  String? get hint => _hint;
  set hint(String? value) {
    if (_hint == value) return;
    _hint = value;
    _changed();
  }

  GSemanticsRole get role => _role;
  set role(GSemanticsRole value) {
    if (_role == value) return;
    _role = value;
    _changed();
  }

  /// Whether this semantic control is enabled.
  ///
  /// Null means the node does not expose an enabled/disabled state.
  bool? get enabled => _enabled;
  set enabled(bool? value) {
    if (_enabled == value) return;
    _enabled = value;
    _changed();
  }

  /// Whether this semantic item is selected.
  ///
  /// Null means the node does not expose selection state.
  bool? get selected => _selected;
  set selected(bool? value) {
    if (_selected == value) return;
    _selected = value;
    _changed();
  }

  /// Whether this semantic item is checked.
  ///
  /// Null means the node does not expose checked state. Checkbox/radio roles
  /// default to unchecked at the Flutter bridge when this is null.
  bool? get checked => _checked;
  set checked(bool? value) {
    if (_checked == value) return;
    _checked = value;
    _changed();
  }

  /// Whether this semantic item is toggled on.
  ///
  /// Null means the node does not expose toggled state. Toggle roles default
  /// to off at the Flutter bridge when this is null.
  bool? get toggled => _toggled;
  set toggled(bool? value) {
    if (_toggled == value) return;
    _toggled = value;
    _changed();
  }

  /// Merge semantic descendants into this logical platform semantic node.
  bool get mergeDescendants => _mergeDescendants;
  set mergeDescendants(bool value) {
    if (_mergeDescendants == value && (!value || !_excludeDescendants)) return;
    _mergeDescendants = value;
    if (value) _excludeDescendants = false;
    _changed();
  }

  /// Exclude semantic descendants while retaining this node's own semantics.
  bool get excludeDescendants => _excludeDescendants;
  set excludeDescendants(bool value) {
    if (_excludeDescendants == value && (!value || !_mergeDescendants)) return;
    _excludeDescendants = value;
    if (value) _mergeDescendants = false;
    _changed();
  }

  /// Adds or removes one normalized [GAction] exposed to accessibility.
  ///
  /// Only standard actions understood by a platform bridge are surfaced there.
  /// Unknown actions remain valid GraphX actions but are not invented as
  /// platform-specific custom actions by this foundation.
  GNodeSemantics action(GAction action, {bool enabled = true}) {
    var actions = _actions;
    if (enabled) {
      actions ??= <GAction>{};
      if (!actions.add(action)) return this;
      _actions = actions;
    } else {
      if (actions == null || !actions.remove(action)) return this;
      if (actions.isEmpty) _actions = null;
    }
    _changed();
    return this;
  }

  bool supportsAction(GAction action) => _actions?.contains(action) ?? false;

  /// Restores this node to having no semantic annotation.
  void clear() {
    if (!_isAnnotated) return;
    _label = null;
    _value = null;
    _increasedValue = null;
    _decreasedValue = null;
    _hint = null;
    _role = GSemanticsRole.generic;
    _enabled = null;
    _selected = null;
    _checked = null;
    _toggled = null;
    _mergeDescendants = false;
    _excludeDescendants = false;
    _actions = null;
    _changed();
  }

  bool get _isAnnotated =>
      _label != null ||
      _value != null ||
      _increasedValue != null ||
      _decreasedValue != null ||
      _hint != null ||
      _role != GSemanticsRole.generic ||
      _enabled != null ||
      _selected != null ||
      _checked != null ||
      _toggled != null ||
      _mergeDescendants ||
      _excludeDescendants ||
      (_actions?.isNotEmpty ?? false);

  void _changed() {
    final stage = _node._stage;
    if (stage == null) return;

    final current = _gStageSemantics[stage];
    if (_isAnnotated) {
      final manager = current ?? _ensureStageSemantics(stage);
      manager._nodes.add(_node);
      manager._changed();
      return;
    }

    if (current != null && current._nodes.remove(_node)) current._changed();
  }
}

final Expando<GNodeSemantics> _gNodeSemantics = Expando<GNodeSemantics>(
  'GNode.semantics',
);
final Expando<_GStageSemantics> _gStageSemantics = Expando<_GStageSemantics>(
  'GStage.semantics',
);
final Expando<_GSemanticsHostBridge> _gSemanticsHosts =
    Expando<_GSemanticsHostBridge>('GStage.semanticsHost');

GNodeSemantics? _maybeNodeSemantics(GNode node) => _gNodeSemantics[node];

GNodeSemantics _ensureNodeSemantics(GNode node) {
  if (node.isDisposed) {
    throw StateError('Cannot access semantics on a disposed node.');
  }
  return _gNodeSemantics[node] ??= GNodeSemantics._(node);
}

extension GNodeSemanticsApi on GNode {
  /// Whether this node currently contributes semantic information.
  ///
  /// This getter never allocates semantic state.
  bool get hasSemantics => _maybeNodeSemantics(this)?._isAnnotated ?? false;

  /// Semantic metadata and accessibility actions for this retained node.
  ///
  /// The state object is allocated lazily, and merely reading this getter does
  /// not register the node with a Stage semantic domain.
  GNodeSemantics get semantics => _ensureNodeSemantics(this);
}

/// Targeted GAction dispatch used by accessibility and other non-focus input.
///
/// This preserves logical input focus while routing through the same node
/// signals and Stage-global GAction listeners as focused dispatch.
extension GActionTargetDispatch on GActionInput {
  bool dispatchTo(
    GNode target,
    GAction action, {
    GActionPhase phase = GActionPhase.pressed,
    GActionSource source = GActionSource.synthetic,
    double value = 1.0,
  }) {
    final focus = _focus;
    if (target.isDisposed || !identical(target._stage, focus._stage)) {
      return false;
    }

    final event = GActionEvent(
      action: action,
      phase: phase,
      source: source,
      value: value,
      target: target,
    );

    GNode? current = target;
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
    _emitGlobal(event);
    if (event.handled) return true;
    if (phase == GActionPhase.released) return false;

    if (action == GActions.focusNext) return focus.next();
    if (action == GActions.focusPrevious) return focus.previous();
    if (action == GActions.focusLeft) return focus.move(GFocusDirection.left);
    if (action == GActions.focusRight) return focus.move(GFocusDirection.right);
    if (action == GActions.focusUp) return focus.move(GFocusDirection.up);
    if (action == GActions.focusDown) return focus.move(GFocusDirection.down);
    return false;
  }
}

abstract interface class _GSemanticsHostBridge {
  void semanticsChanged();
}

final class _GStageSemantics {
  _GStageSemantics(GStage stage) : _host = _gSemanticsHosts[stage];

  final Set<GNode> _nodes = <GNode>{};
  _GSemanticsHostBridge? _host;

  bool get hasNodes => _nodes.isNotEmpty;

  void _changed() => _host?.semanticsChanged();

  void _bindHost(_GSemanticsHostBridge host) {
    _host = host;
    if (hasNodes) host.semanticsChanged();
  }

  void _unbindHost(_GSemanticsHostBridge host) {
    if (identical(_host, host)) _host = null;
  }
}

_GStageSemantics _ensureStageSemantics(GStage stage) =>
    _gStageSemantics[stage] ??= _GStageSemantics(stage);

void _bindStageSemanticsHost(GStage stage, _GSemanticsHostBridge host) {
  _gSemanticsHosts[stage] = host;
  _gStageSemantics[stage]?._bindHost(host);
}

void _unbindStageSemanticsHost(GStage stage, _GSemanticsHostBridge host) {
  if (identical(_gSemanticsHosts[stage], host)) _gSemanticsHosts[stage] = null;
  _gStageSemantics[stage]?._unbindHost(host);
}

void _semanticsNodeAttached(GNode node, GStage stage) {
  final state = _maybeNodeSemantics(node);
  if (state == null || !state._isAnnotated) return;
  final manager = _ensureStageSemantics(stage);
  if (manager._nodes.add(node)) manager._changed();
}

void _semanticsNodeDetached(GNode node, GStage stage) {
  final manager = _gStageSemantics[stage];
  if (manager != null && manager._nodes.remove(node)) manager._changed();
}

void _disposeNodeSemantics(GNode node) {
  final state = _maybeNodeSemantics(node);
  if (state == null) return;
  final stage = node._stage;
  if (stage != null) {
    final manager = _gStageSemantics[stage];
    if (manager != null && manager._nodes.remove(node)) manager._changed();
  }
  _gNodeSemantics[node] = null;
}

/// Marks scene-derived semantic properties dirty without allocating a semantic
/// manager for scenes that do not use semantics.
void _semanticsSceneChanged(GNode node) {
  final stage = node._stage;
  if (stage == null) return;
  final manager = _gStageSemantics[stage];
  if (manager != null && manager.hasNodes) manager._changed();
}
