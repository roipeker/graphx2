part of 'package:graphx/src/graphx_impl.dart';

abstract class _GDisposable {
  bool get isDisposed;
  void dispose();
}

abstract interface class GUpdatable {
  bool get updatesEnabled;
  void update(double delta);
}

mixin GStageUpdatable implements GUpdatable {
  int _updateSlot = -1;
}

final Expando<_GDetachedRenderLock> _detachedRenderLocks =
    Expando<_GDetachedRenderLock>('graphx.detachedRenderLock');

final class _GDetachedRenderLock {
  int depth = 0;
}

@pragma('track-creation-locations')
class GNode with GNodeTransform, GStageUpdatable implements _GDisposable {
  GNode({this.name});

  String? name;

  @override
  String toString() {
    final value = name;
    if (value != null && value.isNotEmpty) return 'Node#$value';
    return '$runtimeType#${identityHashCode(this).toRadixString(16)}';
  }

  GNode? _parent;
  GNode? get parent => _parent;

  GStage? _stage;
  GStage get stage =>
      _stage ?? (throw StateError('Node is not attached to stage.'));

  /// Whether this node has crossed the Stage lifecycle attachment boundary.
  ///
  /// Stage ownership may exist before this becomes true: [GStage.mount] claims
  /// the tree immediately, while lifecycle attachment waits for a usable
  /// viewport.
  bool get isAttached => _stage?._rootAttached ?? false;

  GNode get _detachedTreeRoot {
    var node = this;
    while (node._parent != null) {
      node = node._parent!;
    }
    return node;
  }

  void _checkStructureMutation() {
    final stage = _stage;
    if (stage != null) {
      stage._checkStructureMutation();
      return;
    }
    final lock = _detachedRenderLocks[_detachedTreeRoot];
    if (lock != null && lock.depth != 0) {
      throw StateError('Scene structure cannot be mutated during render.');
    }
  }

  _GDetachedRenderLock _beginDetachedRenderPass() {
    assert(_stage == null);
    final root = _detachedTreeRoot;
    var lock = _detachedRenderLocks[root];
    if (lock == null) {
      lock = _GDetachedRenderLock();
      _detachedRenderLocks[root] = lock;
    }
    lock.depth++;
    return lock;
  }

  void _endDetachedRenderPass(_GDetachedRenderLock lock) {
    assert(lock.depth > 0);
    if (lock.depth > 0) lock.depth--;
  }

  GNodeCache? _cache;

  double _alpha = 1.0;
  double get alpha => _alpha;
  set alpha(double value) {
    assert(value.isFinite);
    value = value.clamp(0.0, 1.0);
    if (_alpha == value) return;
    _alpha = value;
    _semanticsSceneChanged(this);
    invalidatePaint();
  }

  _GNodeComposite? _composite;

  GCompositeMode get compositeMode => _composite?.mode ?? GCompositeMode.auto;
  set compositeMode(GCompositeMode value) {
    if (compositeMode == value) return;
    final state = _composite ??= _GNodeComposite();
    state.mode = value;
    if (state.isDefault) _composite = null;
    invalidatePaint();
  }

  ui.BlendMode get blendMode => _composite?.blendMode ?? ui.BlendMode.srcOver;
  set blendMode(ui.BlendMode value) {
    if (blendMode == value) return;
    final state = _composite ??= _GNodeComposite();
    state.blendMode = value;
    if (state.isDefault) _composite = null;
    invalidatePaint();
  }

  bool _visible = true;
  bool get visible => _visible;
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _focusNodeStateChanged(this);
    _semanticsSceneChanged(this);
    invalidatePaint();
  }

  bool _active = true;
  bool get active => _active;
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    _focusNodeStateChanged(this);
    _semanticsSceneChanged(this);
    final stage = _stage;
    if (stage != null && _updatesEnabled) {
      if (value) {
        stage._addUpdater(this);
      } else {
        stage._removeUpdater(this);
      }
    }
    invalidatePaint();
  }

  bool _paintSelf = false;

  GNodePointer? _pointer;
  int _pointerSubtreeInterest = 0;
  int _pointerHoverSubtreeInterest = 0;

  GNodePointer get pointer => (_pointer ??= GNodePointer._(this));

  void _adjustPointerSubtreeInterest(int delta) {
    if (delta == 0) return;
    GNode? node = this;
    while (node != null) {
      node._pointerSubtreeInterest += delta;
      assert(node._pointerSubtreeInterest >= 0);
      node = node._parent;
    }
    if (delta > 0) _stage?._ensureNodePointerRouter();
  }

  void _adjustPointerHoverSubtreeInterest(int delta) {
    if (delta == 0) return;
    GNode? node = this;
    while (node != null) {
      node._pointerHoverSubtreeInterest += delta;
      assert(node._pointerHoverSubtreeInterest >= 0);
      node = node._parent;
    }
  }

  GBounds? _selfBoundsCache;
  GBounds? _localBoundsCache;
  bool _selfBoundsDirty = true;
  bool _localBoundsDirty = true;

  @protected
  void computeSelfBounds(GBounds out) => out.setEmpty();

  GBounds getLocalBounds([GBounds? out]) {
    final result = out ?? GBounds.empty();
    result.copyFrom(_ensureLocalBounds());
    return result;
  }

  GBounds get localBounds => getLocalBounds();

  GBounds getBounds(GNode targetSpace, [GBounds? out]) =>
      _getNodeBounds(this, targetSpace, out);

  /// Marks this node's intrinsic bounds as changed.
  @protected
  void invalidateBounds() {
    _selfBoundsDirty = true;
    // Intrinsic consumers only need the direct ownership boundary. If that
    // parent derives a new intrinsic size it will invalidate its own bounds and
    // notify its parent in turn. Visual local-bounds dirtiness keeps the older
    // short-circuiting propagation below.
    _parent?.childBoundsChanged(this);
    _invalidateLocalBoundsUp();
    _semanticsSceneChanged(this);
  }

  /// Marks this node's rendered pixels as changed and invalidates any retained
  /// raster caches containing it. This is intentionally mutation-path work;
  /// ordinary traversal pays no ancestor bookkeeping cost.
  @protected
  void invalidatePaint() {
    final ownCache = _cache;
    if (ownCache != null && ownCache.enabled) ownCache._invalidate();
    final stage = _stage;
    if (stage == null ||
        stage._rasterCacheCount > ((ownCache?.enabled ?? false) ? 1 : 0)) {
      _invalidateCachedAncestors(includeSelf: false);
    }
    stage?.requestPaint();
  }

  void _invalidateCachedAncestors({required bool includeSelf}) {
    GNode? node = includeSelf ? this : _parent;
    while (node != null) {
      final cache = node._cache;
      if (cache != null && cache.enabled) cache._invalidate();
      node = node._parent;
    }
  }

  GBounds _ensureSelfBounds() => _ensureNodeSelfBounds(this);
  GBounds _ensureLocalBounds() => _ensureNodeLocalBounds(this);

  void _invalidateLocalBoundsUp() {
    _localBoundsDirty = true;
    var node = _parent;
    while (node != null) {
      if (node._localBoundsDirty) return;
      node._localBoundsDirty = true;
      node = node._parent;
    }
  }

  void _invalidateParentBounds() => _parent?._invalidateLocalBoundsUp();

  bool hitTestLocal(double x, double y) => _ensureSelfBounds().contains(x, y);

  bool _updatesEnabled = false;

  @protected
  void setPaintSelf(bool flag) {
    _paintSelf = flag;
  }

  @override
  bool get updatesEnabled => _updatesEnabled && _active;
  set updatesEnabled(bool value) {
    if (_updatesEnabled == value) return;
    _updatesEnabled = value;
    final stage = _stage;
    if (stage == null) return;
    if (value) {
      stage._addUpdater(this);
    } else {
      stage._removeUpdater(this);
    }
  }

  @override
  @protected
  void update(double delta) {}

  List<GNode>? _children;
  List<GNode>? _childrenSnapshot;

  List<GNode> get children => _childrenSnapshot ??= List<GNode>.unmodifiable(
    _children ?? const <GNode>[],
  );

  int get numChildren => _children?.length ?? 0;

  GNode getChildAt(int index) => (_children ?? const <GNode>[])[index];

  int getChildIndex(GNode child) => _children?.indexOf(child) ?? -1;

  GNode? getChildByName(String name) {
    final children = _children;
    if (children == null) return null;
    for (var i = 0; i < children.length; ++i) {
      final child = children[i];
      if (child.name == name) return child;
    }
    return null;
  }

  /// Called after this node's direct child ordering or membership changes.
  ///
  /// Extension packages can override this to retain derived child state without
  /// putting package-specific concepts into core scene ownership.
  @protected
  void childrenChanged() {}

  /// Called when a direct child's intrinsic self bounds may have changed.
  ///
  /// Notifications originate from authored geometry, not ordinary transform
  /// mutations. A derived parent that changes its own intrinsic geometry should
  /// call [invalidateBounds], naturally forwarding one ownership level.
  @protected
  void childBoundsChanged(GNode child) {}

  /// Called when the inherited [GDefaults] environment for this node may have
  /// changed.
  ///
  /// This is mutation-path work only. Extension packages can override it to
  /// invalidate retained package-specific defaults or theme state. It is also
  /// delivered recursively when a subtree enters, leaves, or moves between
  /// defaults scopes, so consumers do not need per-frame ancestor checks.
  @protected
  void inheritedDefaultsChanged() {}

  GNodeSignals? _signals;
  GNodeSignals get signals => (_signals ??= GNodeSignals());

  bool _disposed = false;
  @override
  bool get isDisposed => _disposed;

  @protected
  void paintSelf(GRenderContext context) {}

  GMatrix2 get worldMatrix {
    _ensureWorldTransform();
    return _worldMatrix!;
  }

  void copyWorldMatrixInto(GMatrix2 out) {
    _ensureWorldTransform();
    out.copyFrom(_worldMatrix!);
  }

  void localToGlobalInto(double x, double y, GPoint out) {
    _ensureWorldTransform();
    _stage?._activeStats?.transform.localToGlobal.increment();
    _worldMatrix!.transformPointInto(x, y, out);
  }

  GPoint localToGlobal(double x, double y) {
    final out = GPoint();
    localToGlobalInto(x, y, out);
    return out;
  }

  bool globalToLocalInto(double x, double y, GPoint out) {
    _ensureWorldTransform();
    _stage?._activeStats?.transform.globalToLocal.increment();
    return _worldMatrix!.inverseTransformPointInto(x, y, out);
  }

  GPoint? globalToLocal(double x, double y) {
    final out = GPoint();
    return globalToLocalInto(x, y, out) ? out : null;
  }

  void _ensureWorldTransform() {
    final parent = _parent;
    if (parent != null) parent._ensureWorldTransform();
    final parentVersion = parent?._worldTransformVersion ?? 0;

    if (_worldLocalTransformVersion == _localTransformVersion &&
        identical(_worldTransformParent, parent) &&
        _worldParentTransformVersion == parentVersion) {
      _stage?._activeStats?.transform.worldMatrixCacheHits.increment();
      return;
    }

    final transformed = hasLocalTransform;
    final world = _worldMatrix ??= GMatrix2();
    if (parent == null) {
      if (transformed) {
        world.copyFrom(localMatrix);
      } else {
        world.identity();
      }
    } else if (transformed) {
      world.setProduct(parent._worldMatrix!, localMatrix);
    } else {
      world.copyFrom(parent._worldMatrix!);
    }

    _worldLocalTransformVersion = _localTransformVersion;
    _worldTransformParent = parent;
    _worldParentTransformVersion = parentVersion;
    _worldTransformVersion++;
    _stage?._activeStats?.transform.worldMatrixUpdates.increment();
  }

  int _worldLocalTransformVersion = -1;
  int _worldParentTransformVersion = -1;
  int _worldTransformVersion = 0;
  GNode? _worldTransformParent;

  @override
  void _onTransformChanged() {
    _stage?._activeStats?.transform.invalidations.increment();
    _invalidateParentBounds();
    // This node's own raster remains valid; only a cached ancestor contains
    // this local transform as part of its pixels.
    final stage = _stage;
    if (stage == null || stage._rasterCacheCount != 0) {
      _invalidateCachedAncestors(includeSelf: false);
    }
    _semanticsSceneChanged(this);
    stage?.requestPaint();
  }

  @override
  void _onLocalMatrixUpdated() {
    _stage?._activeStats?.transform.localMatrixUpdates.increment();
  }

  @override
  void _onLocalMatrixAssigned() {
    _stage?._activeStats?.transform.localMatrixAssignments.increment();
  }

  @override
  void _onLocalMatrixMaterialized() {
    _stage?._activeStats?.transform.localMatrixMaterializations.increment();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _checkStructureMutation();
    _disposeNodeFocus(this);
    _disposeNodeSemantics(this);
    _disposed = true;
    _parent?.removeChild(this);
    _pointer?.dispose();
    _cache?.dispose();

    final children = _children;
    _children = null;
    _childrenSnapshot = null;
    if (children != null) {
      for (var i = children.length - 1; i >= 0; --i) {
        final child = children[i];
        child._detachFromStage();
        child._parent = null;
        child.dispose();
      }
    }
    _signals?.dispose();
  }

  T addChild<T extends GNode>(T child) {
    if (_disposed) {
      throw StateError('Cannot add a child to a disposed node.');
    }
    if (child._disposed) {
      throw StateError('Cannot add a disposed node.');
    }
    if (identical(child, this)) {
      throw ArgumentError('A node cannot be added as a child of itself.');
    }
    for (GNode? node = this; node != null; node = node._parent) {
      if (identical(node, child)) {
        throw ArgumentError(
          'A node cannot be added below one of its descendants.',
        );
      }
    }

    _checkStructureMutation();
    child._checkStructureMutation();

    final oldParent = child._parent;
    if (identical(oldParent, this)) {
      final children = _children!;
      final index = children.indexOf(child);
      assert(index >= 0);
      if (index == children.length - 1) return child;
      children.removeAt(index);
      children.add(child);
      _childrenSnapshot = null;
      childrenChanged();
      _semanticsSceneChanged(child);
      invalidatePaint();
      return child;
    }

    final oldStage = child._stage;
    final newStage = _stage;
    if (oldParent == null && oldStage != null) {
      throw StateError('An attached stage root cannot be reparented.');
    }
    final sameStage = identical(oldStage, newStage);

    if (oldParent != null) {
      oldParent._unlinkChild(child, detachStage: !sameStage);
    }

    final children = _children ??= [];
    children.add(child);
    _childrenSnapshot = null;
    child._parent = this;
    _defaultsReparented(child, oldParent, this);
    if (sameStage && newStage != null && oldParent != null) {
      if (newStage._rootAttached) {
        _focusNodeReparented(child, oldParent, this);
      }
      _semanticsSceneChanged(child);
    }
    childrenChanged();
    _invalidateLocalBoundsUp();
    if (child._pointerSubtreeInterest != 0) {
      _adjustPointerSubtreeInterest(child._pointerSubtreeInterest);
    }
    if (child._pointerHoverSubtreeInterest != 0) {
      _adjustPointerHoverSubtreeInterest(child._pointerHoverSubtreeInterest);
    }
    if (!sameStage && newStage != null) child._attachToStage(newStage);

    if (!identical(oldStage, newStage)) oldStage?.requestPaint();
    invalidatePaint();
    return child;
  }

  void removeFromParent() {
    _parent?.removeChild(this);
  }

  void removeChild(GNode child) {
    if (child._parent != this) return;
    _checkStructureMutation();
    _unlinkChild(child, detachStage: true);
    _defaultsReparented(child, this, null);
    invalidatePaint();
  }

  void _unlinkChild(GNode child, {required bool detachStage}) {
    final children = _children;
    if (children == null || !children.remove(child)) return;
    _childrenSnapshot = null;
    childrenChanged();
    _invalidateLocalBoundsUp();
    if (child._pointerSubtreeInterest != 0) {
      _adjustPointerSubtreeInterest(-child._pointerSubtreeInterest);
    }
    if (child._pointerHoverSubtreeInterest != 0) {
      _adjustPointerHoverSubtreeInterest(-child._pointerHoverSubtreeInterest);
    }
    if (detachStage) child._detachFromStage();
    child._parent = null;
    if (children.isEmpty) _children = null;
  }

  void _attachToStage(GStage stage) {
    if (_disposed) throw StateError('Cannot attach a disposed node.');
    if (identical(_stage, stage)) return;
    if (_stage != null) {
      throw StateError('Node is already attached to another stage');
    }
    _stage = stage;
    stage._nodeCount++;
    _cache?._attachStage(stage);
    _semanticsNodeAttached(this, stage);
    if (_pointerSubtreeInterest != 0) stage._ensureNodePointerRouter();
    if (_updatesEnabled) stage._addUpdater(this);
    final children = _children;
    if (children != null) {
      for (var i = 0; i < children.length; ++i) {
        children[i]._attachToStage(stage);
      }
    }
    if (stage._rootAttached) _dispatchAttachedSelf();
  }

  void _dispatchAttachedSubtree() {
    final children = _children;
    if (children != null) {
      for (var i = 0; i < children.length; ++i) {
        children[i]._dispatchAttachedSubtree();
      }
    }
    _dispatchAttachedSelf();
  }

  void _dispatchAttachedSelf() {
    final stage = _stage;
    if (stage == null) {
      throw StateError('Node must belong to a stage before attachment.');
    }
    _focusNodeAttached(this, stage);
    _signals?._attached?.emit();
    attached();
  }

  void _detachFromStage() {
    final stage = _stage;
    if (stage == null) return;
    final notifyLifecycle = stage._rootAttached;
    if (notifyLifecycle) _focusNodeDetached(this, stage);
    _semanticsNodeDetached(this, stage);
    if (_updatesEnabled) stage._removeUpdater(this);
    final children = _children;
    if (children != null) {
      for (var i = 0; i < children.length; ++i) {
        children[i]._detachFromStage();
      }
    }
    if (notifyLifecycle) {
      _signals?._detached?.emit();
      detached();
    }
    _cache?._detachStage(stage);
    stage._nodeCount--;
    assert(stage._nodeCount >= 0);
    _stage = null;
  }

  @protected
  void attached() {}

  @protected
  void detached() {}
}

final class GNodeSignals implements _GDisposable {
  GSignal0? _attached;
  GSignal0? _detached;
  GSignal0? _dispose;

  GSignal0 get onAttached => (_attached ??= GSignal0());
  GSignal0 get onDetached => (_detached ??= GSignal0());

  /// Emitted once after this node is detached and its descendants are disposed,
  /// immediately before the node signal surface is torn down.
  GSignal0 get onDispose => (_dispose ??= GSignal0());

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dispose?.emit();
    _attached?.dispose();
    _detached?.dispose();
    _dispose?.dispose();
  }

  bool _disposed = false;
  @override
  bool get isDisposed => _disposed;
}
