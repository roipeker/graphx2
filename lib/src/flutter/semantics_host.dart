part of 'package:graphx/src/graphx_impl.dart';

/// Flutter semantics gateway for the canvas-backed GraphX surface.
///
/// The retained GNode scene remains the source of semantic identity. This
/// render object owns only the platform adapter nodes and reuses them across
/// updates so dynamic values/transforms do not churn Flutter objects.
final class _GSemanticsHost extends SingleChildRenderObjectWidget {
  const _GSemanticsHost({required this.stage, required super.child});

  final GStage stage;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderGSemanticsHost(
      stage,
      Directionality.maybeOf(context) ?? ui.TextDirection.ltr,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderGSemanticsHost renderObject,
  ) {
    renderObject
      ..stage = stage
      ..textDirection = Directionality.maybeOf(context) ?? ui.TextDirection.ltr;
  }
}

final class _RenderGSemanticsHost extends RenderProxyBox
    implements _GSemanticsHostBridge {
  _RenderGSemanticsHost(this._stage, this._textDirection);

  GStage _stage;
  ui.TextDirection _textDirection;
  Map<GNode, SemanticsNode>? _semanticNodes;
  Map<GNode, GSignalSubscription>? _focusSubscriptions;

  final GBounds _bounds = GBounds.empty();
  final GBounds _clipBounds = GBounds.empty();
  final GPoint _p0 = GPoint();
  final GPoint _p1 = GPoint();
  final GPoint _p2 = GPoint();
  final GPoint _p3 = GPoint();

  GStage get stage => _stage;
  set stage(GStage value) {
    if (identical(_stage, value)) return;
    if (attached) _unbindStageSemanticsHost(_stage, this);
    _clearFocusSubscriptions();
    _stage = value;
    _semanticNodes = null;
    if (attached) _bindStageSemanticsHost(_stage, this);
    markNeedsSemanticsUpdate();
  }

  ui.TextDirection get textDirection => _textDirection;
  set textDirection(ui.TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _bindStageSemanticsHost(_stage, this);
  }

  @override
  void detach() {
    _unbindStageSemanticsHost(_stage, this);
    _clearFocusSubscriptions();
    super.detach();
  }

  @override
  void semanticsChanged() {
    if (attached) markNeedsSemanticsUpdate();
  }

  bool get _hasGraphXSemantics {
    final domain = _gStageSemantics[_stage];
    if (domain == null || !domain.hasNodes) return false;
    for (final node in domain._nodes) {
      if (_isBridgeNode(node)) return true;
    }
    return false;
  }

  bool _isBridgeNode(GNode node) {
    return node is! GPortal<dynamic> &&
        !node.isDisposed &&
        identical(node._stage, _stage) &&
        (_maybeNodeSemantics(node)?._isAnnotated ?? false);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (!_hasGraphXSemantics) return;
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true;
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode root,
    SemanticsConfiguration rootConfig,
    Iterable<SemanticsNode> inheritedChildren,
  ) {
    final domain = _gStageSemantics[_stage];
    if (domain == null || !domain.hasNodes) {
      _semanticNodes = null;
      _clearFocusSubscriptions();
      super.assembleSemanticsNode(root, rootConfig, inheritedChildren);
      return;
    }

    final registered = <GNode>[
      for (final node in domain._nodes)
        if (_isBridgeNode(node)) node,
    ];
    if (registered.isEmpty) {
      _semanticNodes = null;
      _clearFocusSubscriptions();
      super.assembleSemanticsNode(root, rootConfig, inheritedChildren);
      return;
    }

    registered.sort(_compareSceneOrder);
    final registeredSet = registered.toSet();
    final included = <GNode>[];
    final includedSet = <GNode>{};

    for (final node in registered) {
      if (_isExcludedByAncestor(node)) continue;
      included.add(node);
      includedSet.add(node);
    }
    _syncFocusSubscriptions(included);

    final semanticParent = <GNode, GNode?>{};
    final semanticChildren = <GNode, List<GNode>>{};
    final roots = <GNode>[];
    for (final node in included) {
      final parent = _nearestSemanticParent(node, includedSet);
      semanticParent[node] = parent;
      if (parent == null) {
        roots.add(node);
      } else {
        (semanticChildren[parent] ??= <GNode>[]).add(node);
      }
    }

    final cache = _semanticNodes ??= <GNode, SemanticsNode>{};
    final mergedIntoParent = <GNode, bool>{};
    for (final node in included) {
      final parent = semanticParent[node];
      final parentState = parent == null ? null : _maybeNodeSemantics(parent);
      mergedIntoParent[node] =
          parent != null &&
          ((parentState?._mergeDescendants ?? false) ||
              (mergedIntoParent[parent] ?? false));
    }

    for (var i = included.length - 1; i >= 0; --i) {
      final node = included[i];
      final state = _maybeNodeSemantics(node)!;
      final semanticNode = cache.putIfAbsent(
        node,
        () => SemanticsNode(key: ObjectKey(node)),
      );
      final config = _configurationFor(node, state);
      final parent = semanticParent[node];
      final transform = _transformToSemanticParent(node, parent);
      final visible =
          _isEffectivelyVisible(node) &&
          !_isFullyOutsideRectClip(node) &&
          transform != null;
      config.isHidden = !visible;

      _boundsFor(node, _bounds);
      semanticNode
        ..rect = _bounds.isEmpty
            ? ui.Rect.zero
            : ui.Rect.fromLTRB(_bounds.x1, _bounds.y1, _bounds.x2, _bounds.y2)
        ..transform = transform ?? Matrix4.identity()
        ..isMergedIntoParent = mergedIntoParent[node] ?? false;

      final childNodes = <SemanticsNode>[
        for (final child in semanticChildren[node] ?? const <GNode>[])
          cache[child]!,
      ];
      semanticNode.updateWith(
        config: config,
        childrenInInversePaintOrder: childNodes.reversed.toList(),
      );
    }

    final rootChildren = <SemanticsNode>[
      for (final node in roots) cache[node]!,
    ];
    rootChildren.addAll(inheritedChildren);
    root.updateWith(
      config: rootConfig,
      childrenInInversePaintOrder: rootChildren.reversed.toList(),
    );

    // Keep cached nodes for excluded-but-still-registered GNodes so a temporary
    // exclude toggle does not allocate new semantic identities. Detached or
    // de-annotated nodes are pruned.
    cache.removeWhere((node, _) => !registeredSet.contains(node));
  }

  SemanticsConfiguration _configurationFor(GNode node, GNodeSemantics state) {
    final config = SemanticsConfiguration()
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..textDirection = _textDirection;

    final label = state._label;
    if (label != null) config.label = label;
    final value = state._value;
    if (value != null) config.value = value;
    final increasedValue = state._increasedValue;
    if (increasedValue != null) config.increasedValue = increasedValue;
    final decreasedValue = state._decreasedValue;
    if (decreasedValue != null) config.decreasedValue = decreasedValue;
    final hint = state._hint;
    if (hint != null) config.hint = hint;

    final enabled = _effectiveEnabled(node, state);
    if (enabled != null) config.isEnabled = enabled;
    final selected = state._selected;
    if (selected != null) config.isSelected = selected;
    final checked = state._checked;
    final toggled = state._toggled;

    switch (state._role) {
      case GSemanticsRole.generic:
      case GSemanticsRole.text:
        break;
      case GSemanticsRole.button:
        config.isButton = true;
      case GSemanticsRole.image:
        config.isImage = true;
      case GSemanticsRole.toggle:
        config.isToggled = toggled ?? false;
      case GSemanticsRole.checkbox:
        config.isChecked = checked ?? false;
      case GSemanticsRole.radio:
        config
          ..isChecked = checked ?? false
          ..isInMutuallyExclusiveGroup = true;
      case GSemanticsRole.slider:
        config.isSlider = true;
      case GSemanticsRole.menu:
        config.role = ui.SemanticsRole.menu;
      case GSemanticsRole.menuItem:
        config.role = ui.SemanticsRole.menuItem;
    }

    if (checked != null &&
        state._role != GSemanticsRole.checkbox &&
        state._role != GSemanticsRole.radio) {
      config.isChecked = checked;
    }
    if (toggled != null && state._role != GSemanticsRole.toggle) {
      config.isToggled = toggled;
    }

    if (state._mergeDescendants) {
      config.isMergingSemanticsOfDescendants = true;
    }

    final focusable = enabled != false && node.focusable;
    if (focusable) {
      // Match Flutter's interactive-control semantics without conflating
      // platform accessibility focus with GraphX's logical input focus.
      config
        ..isFocused = node.hasFocus
        ..onFocus = () {
          if (!node.hasFocus) node.requestFocus();
        };
    }

    if (enabled != false) {
      if (state.supportsAction(GActions.activate)) {
        config.onTap = () => _dispatch(node, GActions.activate);
      }
      if (state.supportsAction(GSemanticsActions.increment)) {
        config.onIncrease = () => _dispatch(node, GSemanticsActions.increment);
      }
      if (state.supportsAction(GSemanticsActions.decrement)) {
        config.onDecrease = () => _dispatch(node, GSemanticsActions.decrement);
      }
      if (state.supportsAction(GSemanticsActions.dismiss) ||
          state.supportsAction(GActions.back)) {
        config.onDismiss = () => _dispatch(
          node,
          state.supportsAction(GSemanticsActions.dismiss)
              ? GSemanticsActions.dismiss
              : GActions.back,
        );
      }
    }
    return config;
  }

  void _syncFocusSubscriptions(List<GNode> included) {
    Set<GNode>? active;
    for (final node in included) {
      if (!node.focusable) continue;
      active ??= <GNode>{};
      active.add(node);
      final subscriptions = _focusSubscriptions ??=
          <GNode, GSignalSubscription>{};
      subscriptions.putIfAbsent(
        node,
        () => node.onFocusChanged.add((_) => semanticsChanged()),
      );
    }

    final subscriptions = _focusSubscriptions;
    if (subscriptions == null) return;
    final keep = active ?? const <GNode>{};
    subscriptions.removeWhere((node, subscription) {
      if (keep.contains(node)) return false;
      subscription.cancel();
      return true;
    });
    if (subscriptions.isEmpty) _focusSubscriptions = null;
  }

  void _clearFocusSubscriptions() {
    final subscriptions = _focusSubscriptions;
    if (subscriptions == null) return;
    for (final subscription in subscriptions.values) {
      subscription.cancel();
    }
    subscriptions.clear();
    _focusSubscriptions = null;
  }

  void _dispatch(GNode node, GAction action) {
    _stage.actions.dispatchTo(
      node,
      action,
      source: GActionSource.accessibility,
    );
  }

  bool? _effectiveEnabled(GNode node, GNodeSemantics state) {
    var hasAction = state._actions?.isNotEmpty ?? false;
    bool active = true;
    GNode? current = node;
    while (current != null) {
      if (!current._active) {
        active = false;
        break;
      }
      current = current._parent;
    }
    final declared = state._enabled;
    if (declared != null) return declared && active;
    return hasAction ? active : null;
  }

  bool _isEffectivelyVisible(GNode node) {
    var alpha = 1.0;
    GNode? current = node;
    while (current != null) {
      if (!current._visible) return false;
      alpha *= current._alpha;
      if (!alpha.isFinite || alpha <= 0.0) return false;
      current = current._parent;
    }
    return true;
  }

  bool _isFullyOutsideRectClip(GNode node) {
    GNode? current = node;
    while (current != null) {
      final clip = current._composite?.clip;
      if (clip is GRectClip) {
        node.getBounds(current, _clipBounds);
        if (!_clipBounds.isEmpty) {
          final rect = clip.rect;
          if (_clipBounds.x2 <= rect.left ||
              _clipBounds.x1 >= rect.right ||
              _clipBounds.y2 <= rect.top ||
              _clipBounds.y1 >= rect.bottom) {
            return true;
          }
        }
      }
      current = current._parent;
    }
    return false;
  }

  bool _isExcludedByAncestor(GNode node) {
    var current = node._parent;
    while (current != null) {
      if (_maybeNodeSemantics(current)?._excludeDescendants ?? false) {
        return true;
      }
      current = current._parent;
    }
    return false;
  }

  GNode? _nearestSemanticParent(GNode node, Set<GNode> included) {
    var current = node._parent;
    while (current != null) {
      if (included.contains(current)) return current;
      current = current._parent;
    }
    return null;
  }

  int _compareSceneOrder(GNode a, GNode b) {
    if (identical(a, b)) return 0;
    final ap = _scenePath(a);
    final bp = _scenePath(b);
    final count = math.min(ap.length, bp.length);
    for (var i = 0; i < count; ++i) {
      final delta = ap[i] - bp[i];
      if (delta != 0) return delta;
    }
    return ap.length - bp.length;
  }

  List<int> _scenePath(GNode node) {
    final reversed = <int>[];
    GNode? current = node;
    while (current?._parent != null) {
      final parent = current!._parent!;
      reversed.add(parent._children!.indexOf(current));
      current = parent;
    }
    return reversed.reversed.toList();
  }

  void _boundsFor(GNode node, GBounds out) {
    node.getLocalBounds(out);
  }

  Matrix4? _transformToSemanticParent(GNode node, GNode? semanticParent) {
    final target = semanticParent ?? _stage.root;
    if (identical(node, target)) return Matrix4.identity();
    if (!_hasInteractionMapperToAncestor(node, target)) {
      return _affineTransformToSemanticParent(node, target);
    }
    return _projectiveTransformToSemanticParent(node, target);
  }

  Matrix4? _affineTransformToSemanticParent(GNode node, GNode target) {
    if (!node.localToNodeInto(target, 0.0, 0.0, _p0) ||
        !node.localToNodeInto(target, 1.0, 0.0, _p1) ||
        !node.localToNodeInto(target, 0.0, 1.0, _p2)) {
      return null;
    }

    final a = _p1.x - _p0.x;
    final b = _p1.y - _p0.y;
    final c = _p2.x - _p0.x;
    final d = _p2.y - _p0.y;
    final determinant = a * d - b * c;
    if (!a.isFinite ||
        !b.isFinite ||
        !c.isFinite ||
        !d.isFinite ||
        !_p0.x.isFinite ||
        !_p0.y.isFinite ||
        !determinant.isFinite ||
        determinant.abs() <= 1e-12) {
      return null;
    }

    final out = Matrix4.identity();
    out.setEntry(0, 0, a);
    out.setEntry(1, 0, b);
    out.setEntry(0, 1, c);
    out.setEntry(1, 1, d);
    out.setEntry(0, 3, _p0.x);
    out.setEntry(1, 3, _p0.y);
    return out;
  }

  Matrix4? _projectiveTransformToSemanticParent(GNode node, GNode target) {
    if (!_interactionLocalToAncestorInto(node, target, 0.0, 0.0, _p0) ||
        !_interactionLocalToAncestorInto(node, target, 1.0, 0.0, _p1) ||
        !_interactionLocalToAncestorInto(node, target, 0.0, 1.0, _p2) ||
        !_interactionLocalToAncestorInto(node, target, 1.0, 1.0, _p3)) {
      return null;
    }

    final x0 = _p0.x;
    final y0 = _p0.y;
    final x1 = _p1.x;
    final y1 = _p1.y;
    final x2 = _p2.x;
    final y2 = _p2.y;
    final x3 = _p3.x;
    final y3 = _p3.y;
    if (!x0.isFinite ||
        !y0.isFinite ||
        !x1.isFinite ||
        !y1.isFinite ||
        !x2.isFinite ||
        !y2.isFinite ||
        !x3.isFinite ||
        !y3.isFinite) {
      return null;
    }

    final dx1 = x1 - x3;
    final dx2 = x2 - x3;
    final dx3 = x0 - x1 - x2 + x3;
    final dy1 = y1 - y3;
    final dy2 = y2 - y3;
    final dy3 = y0 - y1 - y2 + y3;

    double g = 0.0;
    double h = 0.0;
    if (dx3.abs() > 1e-12 || dy3.abs() > 1e-12) {
      final denominator = dx1 * dy2 - dx2 * dy1;
      if (!denominator.isFinite || denominator.abs() <= 1e-12) return null;
      g = (dx3 * dy2 - dx2 * dy3) / denominator;
      h = (dx1 * dy3 - dx3 * dy1) / denominator;
      if (!g.isFinite || !h.isFinite) return null;
    }

    final a = x1 - x0 + g * x1;
    final b = x2 - x0 + h * x2;
    final c = x0;
    final d = y1 - y0 + g * y1;
    final e = y2 - y0 + h * y2;
    final f = y0;
    final determinant = a * (e - f * h) - b * (d - f * g) + c * (d * h - e * g);
    if (!a.isFinite ||
        !b.isFinite ||
        !c.isFinite ||
        !d.isFinite ||
        !e.isFinite ||
        !f.isFinite ||
        !determinant.isFinite ||
        determinant.abs() <= 1e-12) {
      return null;
    }

    final out = Matrix4.identity();
    out.setEntry(0, 0, a);
    out.setEntry(0, 1, b);
    out.setEntry(0, 3, c);
    out.setEntry(1, 0, d);
    out.setEntry(1, 1, e);
    out.setEntry(1, 3, f);
    out.setEntry(3, 0, g);
    out.setEntry(3, 1, h);
    return out;
  }

  @override
  void clearSemantics() {
    _semanticNodes = null;
    _clearFocusSubscriptions();
    super.clearSemantics();
  }
}
