// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Flutter boundary for one GraphX focus domain.
///
/// The outer Flutter tree sees GraphXView as one traversal segment. Two tiny
/// sentinels preserve traversal direction when entering/leaving that segment;
/// the scene itself keeps one real Flutter focus node regardless of how many
/// GraphX nodes are focusable.
final class _GFocusHost extends StatefulWidget {
  const _GFocusHost({
    required this.stage,
    required this.captureRawKeyboard,
    required this.autofocus,
    required this.child,
  });

  final GStage stage;
  final bool captureRawKeyboard;
  final bool autofocus;
  final Widget child;

  @override
  State<_GFocusHost> createState() => _GFocusHostState();
}

final class _GFocusHostState extends State<_GFocusHost> implements _GFocusHostBridge {
  late final FocusNode _before;
  late final FocusNode _engine;
  late final FocusNode _after;

  bool _leavingForward = false;
  bool _leavingBackward = false;
  bool _traversalDirty = false;

  @override
  void initState() {
    super.initState();
    _before = FocusNode(debugLabel: 'GraphXView.before')..addListener(_handleBeforeChanged);
    _engine = FocusNode(debugLabel: 'GraphXView.engine', skipTraversal: true);
    _after = FocusNode(debugLabel: 'GraphXView.after')..addListener(_handleAfterChanged);
    _bindStageFocusHost(widget.stage, this);
  }

  @override
  void didUpdateWidget(covariant _GFocusHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stage, widget.stage)) {
      _unbindStageFocusHost(oldWidget.stage, this);
      _bindStageFocusHost(widget.stage, this);
    }
  }

  bool get _hasTraversableScene => _gStageFocus[widget.stage]?.hasFocusableNodes ?? false;

  @override
  Widget build(BuildContext context) {
    final traversable = _hasTraversableScene;
    _before
      ..canRequestFocus = traversable
      ..skipTraversal = !traversable;
    _engine
      ..canRequestFocus = traversable || widget.captureRawKeyboard || widget.autofocus
      ..skipTraversal = traversable || !widget.captureRawKeyboard;
    _after
      ..canRequestFocus = traversable
      ..skipTraversal = !traversable;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Focus(
            focusNode: _before,
            includeSemantics: false,
            child: const SizedBox.shrink(),
          ),
          Focus(
            focusNode: _engine,
            autofocus: widget.autofocus,
            includeSemantics: false,
            onFocusChange: _handleEngineFocusChanged,
            onKeyEvent: _handleKeyEvent,
            child: widget.child,
          ),
          Focus(
            focusNode: _after,
            includeSemantics: false,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!identical(FocusManager.instance.primaryFocus, node)) {
      return KeyEventResult.ignored;
    }
    final stage = widget.stage;
    if (stage.isDisposed || !stage.input.enabled) {
      return KeyEventResult.ignored;
    }

    final type = switch (event) {
      KeyDownEvent() => GKeyEventType.down,
      KeyRepeatEvent() => GKeyEventType.repeat,
      KeyUpEvent() => GKeyEventType.up,
      _ => null,
    };
    if (type == null) return KeyEventResult.ignored;

    final keyEvent = GKeyEvent(
      type: type,
      logicalKey: event.logicalKey,
      physicalKey: event.physicalKey,
      timestamp: event.timeStamp,
      character: event.character,
    );
    stage.input.keyboard._dispatch(keyEvent);

    final handled = _gStageFocus[stage]?.actions._dispatchKey(keyEvent) ?? false;
    return handled || widget.captureRawKeyboard ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _handleEngineFocusChanged(bool focused) {
    final stage = widget.stage;
    if (stage.isDisposed) return;
    if (!focused) {
      stage.input.keyboard._clear();
      _gStageFocus[stage]?._hostBlurred();
      return;
    }

    if (identical(FocusManager.instance.primaryFocus, _engine)) {
      _adoptLogicalFocusIfNeeded();
    }
  }

  void _adoptLogicalFocusIfNeeded() {
    final manager = _gStageFocus[widget.stage];
    if (manager != null && manager.focusedNode == null && manager.hasFocusableNodes) {
      manager.next();
    }
  }

  void _handleBeforeChanged() {
    if (!_before.hasPrimaryFocus) return;
    if (_leavingBackward) {
      _leavingBackward = false;
      scheduleMicrotask(() {
        if (mounted && _before.hasPrimaryFocus) _before.previousFocus();
      });
      return;
    }
    _gStageFocus[widget.stage]?.next();
  }

  void _handleAfterChanged() {
    if (!_after.hasPrimaryFocus) return;
    if (_leavingForward) {
      _leavingForward = false;
      scheduleMicrotask(() {
        if (mounted && _after.hasPrimaryFocus) _after.nextFocus();
      });
      return;
    }
    _gStageFocus[widget.stage]?.previous();
  }

  @override
  void requestEngineFocus() {
    if (!_engine.hasPrimaryFocus) _engine.requestFocus();
  }

  @override
  void enterPortal(GPortal<dynamic> portal, bool forward) {
    final bridge = portal._link.focusHost;
    if (bridge == null) {
      _gStageFocus[widget.stage]?._portalEntryFailed(portal, forward);
      return;
    }
    bridge.enter(forward);
  }

  @override
  void leaveSequential(bool forward) {
    if (forward) {
      _leavingForward = true;
      _after.requestFocus();
    } else {
      _leavingBackward = true;
      _before.requestFocus();
    }
  }

  @override
  void leaveDirection(GFocusDirection direction) {
    final beforeSkip = _before.skipTraversal;
    final afterSkip = _after.skipTraversal;
    _before.skipTraversal = true;
    _after.skipTraversal = true;
    try {
      _engine.focusInDirection(switch (direction) {
        GFocusDirection.left => TraversalDirection.left,
        GFocusDirection.right => TraversalDirection.right,
        GFocusDirection.up => TraversalDirection.up,
        GFocusDirection.down => TraversalDirection.down,
      });
    } finally {
      _before.skipTraversal = beforeSkip;
      _after.skipTraversal = afterSkip;
    }
  }

  @override
  void traversalChanged() {
    if (!mounted || _traversalDirty) return;
    _traversalDirty = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _traversalDirty = false;
      if (!mounted) return;
      setState(() {});
      if (_engine.hasPrimaryFocus) _adoptLogicalFocusIfNeeded();
    });
  }

  @override
  void dispose() {
    _unbindStageFocusHost(widget.stage, this);
    _before
      ..removeListener(_handleBeforeChanged)
      ..dispose();
    _engine.dispose();
    _after
      ..removeListener(_handleAfterChanged)
      ..dispose();
    super.dispose();
  }
}

/// Focus boundary for the Flutter subtree of one [GPortal].
///
/// Portal entry resolves the first/last root control directly from a private
/// content host. During activation an ancestor traversal gate may still be
/// reflected in skipTraversal, so entry relies on canRequestFocus; native
/// Flutter traversal resumes once the group is active. Sentinels are used only
/// to hand traversal back to GraphX.
final class _GPortalFocusHost extends StatefulWidget {
  const _GPortalFocusHost({required this.portal, required this.child});

  final GPortal<dynamic> portal;
  final Widget child;

  @override
  State<_GPortalFocusHost> createState() => _GPortalFocusHostState();
}

final class _GPortalFocusHostState extends State<_GPortalFocusHost> {
  late final FocusNode _before;
  late final FocusNode _host;
  late final FocusNode _content;
  late final FocusNode _after;
  late final _GPortalTraversalPolicy _policy;

  bool _active = false;
  bool _availabilityScheduled = false;

  @override
  void initState() {
    super.initState();
    _before = FocusNode(debugLabel: 'GPortal.before')..addListener(_handleBeforeChanged);
    _host = FocusNode(
      debugLabel: 'GPortal.host',
      skipTraversal: true,
      canRequestFocus: false,
    )..addListener(_handleHostChanged);
    _content = FocusNode(
      debugLabel: 'GPortal.content',
      skipTraversal: true,
      canRequestFocus: false,
    );
    _after = FocusNode(debugLabel: 'GPortal.after')..addListener(_handleAfterChanged);
    _policy = _GPortalTraversalPolicy(
      _scheduleAvailabilitySync,
      before: _before,
      content: _content,
      after: _after,
    );
    widget.portal._link.focusHost = this;
  }

  @override
  void didUpdateWidget(covariant _GPortalFocusHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.portal, widget.portal)) {
      if (identical(oldWidget.portal._link.focusHost, this)) {
        oldWidget.portal._link.focusHost = null;
      }
      widget.portal._link.focusHost = this;
    }
    _scheduleAvailabilitySync();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleAvailabilitySync();
    return FocusTraversalGroup(
      policy: _policy,
      descendantsAreTraversable: _active,
      child: Focus(
        focusNode: _host,
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            Focus(
              focusNode: _before,
              includeSemantics: false,
              child: const SizedBox.shrink(),
            ),
            Focus(
              focusNode: _content,
              canRequestFocus: false,
              skipTraversal: true,
              includeSemantics: false,
              child: widget.child,
            ),
            Focus(
              focusNode: _after,
              includeSemantics: false,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void enter(bool forward) {
    if (!_active) {
      setState(() => _active = true);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusContentEdge(forward);
      });
      return;
    }
    _focusContentEdge(forward);
  }

  void _focusContentEdge(bool forward) {
    final portal = widget.portal;
    if (!mounted || portal.isDisposed || portal._stage == null) return;

    final target = _policy.contentEdge(forward);
    if (target == null) {
      _entryFailed(forward);
      return;
    }
    target.requestFocus();
  }

  void _handleBeforeChanged() {
    if (!_before.hasPrimaryFocus) return;
    final portal = widget.portal;
    if (portal.isDisposed || portal._stage == null) return;

    final manager = _gStageFocus[portal.stage];
    if (manager != null && identical(manager.focusedNode, portal)) {
      manager.previous();
    }
    if (_active && mounted) setState(() => _active = false);
  }

  void _handleAfterChanged() {
    if (!_after.hasPrimaryFocus) return;
    final portal = widget.portal;
    if (portal.isDisposed || portal._stage == null) return;

    final manager = _gStageFocus[portal.stage];
    if (manager != null && identical(manager.focusedNode, portal)) {
      manager.next();
    }
    if (_active && mounted) setState(() => _active = false);
  }

  void _entryFailed(bool forward) {
    final portal = widget.portal;
    if (!portal.isDisposed && portal._stage != null) {
      _setPortalFocusAvailable(portal, false);
      _gStageFocus[portal.stage]?._portalEntryFailed(portal, forward);
    }
    if (mounted && _active) setState(() => _active = false);
  }

  void _handleHostChanged() {
    final portal = widget.portal;
    if (portal.isDisposed || portal._stage == null) return;

    if (_host.hasFocus) {
      portal.stage.input.keyboard._clear();
      if (!identical(FocusManager.instance.primaryFocus, _before) &&
          !identical(FocusManager.instance.primaryFocus, _after)) {
        _setPortalFocusAvailable(portal, true);
      }
      if (!_active && mounted) setState(() => _active = true);
      portal.stage.focus._portalFocused(portal);
      return;
    }

    _gStageFocus[portal.stage]?._portalBlurred(portal);
    if (_active && mounted) setState(() => _active = false);
  }

  void _scheduleAvailabilitySync() {
    if (_availabilityScheduled) return;
    _availabilityScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _availabilityScheduled = false;
      if (!mounted || widget.portal.isDisposed || widget.portal._stage == null) {
        return;
      }
      var available = false;
      void inspect(FocusNode parent) {
        if (available) return;
        for (final child in parent.children) {
          if (child.canRequestFocus) {
            available = true;
            return;
          }
          inspect(child);
          if (available) return;
        }
      }

      inspect(_content);
      _setPortalFocusAvailable(widget.portal, available);
    });
  }

  @override
  void dispose() {
    if (identical(widget.portal._link.focusHost, this)) {
      widget.portal._link.focusHost = null;
    }
    if (!widget.portal.isDisposed && widget.portal._stage != null) {
      _setPortalFocusAvailable(widget.portal, false);
    }
    _before
      ..removeListener(_handleBeforeChanged)
      ..dispose();
    _host
      ..removeListener(_handleHostChanged)
      ..dispose();
    _content.dispose();
    _after
      ..removeListener(_handleAfterChanged)
      ..dispose();
    super.dispose();
  }
}

final class _GPortalTraversalPolicy extends WidgetOrderTraversalPolicy {
  _GPortalTraversalPolicy(
    this._changed, {
    required this.before,
    required this.content,
    required this.after,
  });

  final VoidCallback _changed;
  final FocusNode before;
  final FocusNode content;
  final FocusNode after;

  List<FocusNode> _rootControls() {
    final controls = <FocusNode>[];
    void collect(FocusNode parent) {
      for (final child in parent.children) {
        if (!child.canRequestFocus || child is FocusScopeNode) {
          collect(child);
          continue;
        }
        controls.add(child);
      }
    }

    collect(content);
    return controls;
  }

  FocusNode? contentEdge(bool forward) {
    final controls = _rootControls();
    if (controls.isEmpty) return null;
    return forward ? controls.first : controls.last;
  }

  @override
  bool next(FocusNode currentNode) {
    final controls = _rootControls();
    final index = controls.indexWhere((node) => identical(node, currentNode));
    if (index < 0) return super.next(currentNode);
    if (index + 1 < controls.length) {
      controls[index + 1].requestFocus();
    } else {
      after.requestFocus();
    }
    return true;
  }

  @override
  bool previous(FocusNode currentNode) {
    final controls = _rootControls();
    final index = controls.indexWhere((node) => identical(node, currentNode));
    if (index < 0) return super.previous(currentNode);
    if (index > 0) {
      controls[index - 1].requestFocus();
    } else {
      before.requestFocus();
    }
    return true;
  }

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final ordered = super.sortDescendants(descendants, currentNode).toList();
    final hasBefore = ordered.remove(before);
    final hasAfter = ordered.remove(after);
    return <FocusNode>[if (hasBefore) before, ...ordered, if (hasAfter) after];
  }

  @override
  void changedScope({FocusNode? node, FocusScopeNode? oldScope}) {
    super.changedScope(node: node, oldScope: oldScope);
    _changed();
  }

  @override
  void invalidateScopeData(FocusScopeNode node) {
    super.invalidateScopeData(node);
    _changed();
  }
}
