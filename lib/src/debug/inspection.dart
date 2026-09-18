part of 'package:graphx/graphx.dart';

// Runtime inspection intentionally lives in core because this library owns the
// authoritative private scene state. The wire protocol is debug/profile-only;
// DevTools, CLI tools and other clients can consume it without core depending
// on any DevTools package.
const int _gInspectorProtocolVersion = 1;
const int _gInspectorDefaultPageSize = 200;
const int _gInspectorMaxPageSize = 1000;

final _GInspectorRuntime _gInspectorRuntime = _GInspectorRuntime();

final class _GInspectorRuntime {
  static const _prefix = 'ext.graphx.inspector';

  final List<WeakReference<GStage>> _stages = <WeakReference<GStage>>[];
  final Expando<String> _stageIds = Expando<String>('graphx.inspector.stageId');
  final Expando<String> _objectIds = Expando<String>(
    'graphx.inspector.objectId',
  );
  final Map<String, WeakReference<GStage>> _stageById =
      <String, WeakReference<GStage>>{};
  final Map<String, WeakReference<Object>> _objectById =
      <String, WeakReference<Object>>{};
  final Expando<_GInspectorSelection> _selection =
      Expando<_GInspectorSelection>('graphx.inspector.selection');

  int _nextStageId = 1;
  int _nextObjectId = 1;
  bool _extensionsRegistered = false;

  void registerStage(GStage stage) {
    assert(!kReleaseMode);
    _ensureExtensionsRegistered();
    _idForStage(stage);
    _stages.add(WeakReference<GStage>(stage));
  }

  void unregisterStage(GStage stage) {
    assert(!kReleaseMode);
    final id = _stageIds[stage];
    if (id != null) _stageById.remove(id);
    _selection[stage] = null;
  }

  void _ensureExtensionsRegistered() {
    if (_extensionsRegistered) return;
    _extensionsRegistered = true;
    developer.registerExtension('$_prefix.getInfo', _handleGetInfo);
    developer.registerExtension('$_prefix.listStages', _handleListStages);
    developer.registerExtension('$_prefix.getChildren', _handleGetChildren);
    developer.registerExtension('$_prefix.getPath', _handleGetPath);
    developer.registerExtension('$_prefix.inspectObject', _handleInspectObject);
    // Kept during protocol-v1 bring-up so older local clients fail softly while
    // the UI migrates to the object-oriented command.
    developer.registerExtension('$_prefix.inspectNode', _handleInspectNode);
    developer.registerExtension('$_prefix.pick', _handlePick);
    developer.registerExtension('$_prefix.setSelection', _handleSetSelection);
  }

  Future<developer.ServiceExtensionResponse> _handleGetInfo(
    String method,
    Map<String, String> parameters,
  ) async {
    return _result(<String, Object>{
      'protocolVersion': _gInspectorProtocolVersion,
      'service': 'graphx.inspector',
      // Semantic capabilities are intentionally independent of client UI names
      // and RPC spellings. Keep this list authoritative for protocol v1.
      'capabilities': const <String>[
        'stages',
        'tree.children',
        'tree.path',
        'object.inspect',
        'object.references',
        'object.source.creation',
        'scene.pick',
        'scene.highlight',
        'scene.picker',
        'node.diagnostics',
        'resources.inventory',
        'resources.references',
        'render.overview',
        'render.explain',
        'render.instrumentation',
        'activity.capture',
        'visual.capture',
      ],
    });
  }

  Future<developer.ServiceExtensionResponse> _handleListStages(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stages = _liveStages();
      return _result(<String, Object>{
        'stages': <Object>[for (final stage in stages) _stageSummary(stage)],
      });
    } catch (error) {
      return _extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleGetChildren(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final node = _requireNode(parameters['nodeId']);
      final offset = _parseInt(parameters, 'offset', defaultValue: 0);
      final requestedLimit = _parseInt(
        parameters,
        'limit',
        defaultValue: _gInspectorDefaultPageSize,
      );
      if (offset < 0 || requestedLimit <= 0) {
        return _invalidParams('offset must be >= 0 and limit must be > 0.');
      }
      final limit = math.min(requestedLimit, _gInspectorMaxPageSize);
      final children = node._children;
      final total = children?.length ?? 0;
      final start = math.min(offset, total);
      final end = math.min(start + limit, total);
      return _result(<String, Object>{
        'nodeId': _idForObject(node),
        'offset': start,
        'limit': limit,
        'total': total,
        'children': <Object>[
          if (children != null)
            for (var i = start; i < end; ++i) _nodeSummary(children[i]),
        ],
      });
    } on FormatException catch (error) {
      return _invalidParams(error.message);
    } on StateError catch (error) {
      return _notFound(error.message);
    } catch (error) {
      return _extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleGetPath(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final node = _requireNode(parameters['nodeId']);
      final path = <GNode>[];
      for (GNode? current = node; current != null; current = current._parent) {
        path.add(current);
      }
      return _result(<String, Object>{
        'path': <Object>[
          for (var i = path.length - 1; i >= 0; --i) _nodeSummary(path[i]),
        ],
      });
    } on FormatException catch (error) {
      return _invalidParams(error.message);
    } on StateError catch (error) {
      return _notFound(error.message);
    } catch (error) {
      return _extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleInspectObject(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final object = _requireObject(parameters['objectId']);
      return _result(<String, Object?>{'object': _inspectObject(object)});
    } on FormatException catch (error) {
      return _invalidParams(error.message);
    } on StateError catch (error) {
      return _notFound(error.message);
    } catch (error) {
      return _extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleInspectNode(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final node = _requireNode(parameters['nodeId']);
      return _result(<String, Object?>{'node': _inspectNode(node)});
    } on FormatException catch (error) {
      return _invalidParams(error.message);
    } on StateError catch (error) {
      return _notFound(error.message);
    } catch (error) {
      return _extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handlePick(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _requireStage(parameters['stageId']);
      final x = _parseDouble(parameters, 'x');
      final y = _parseDouble(parameters, 'y');
      final node = stage.hitTest(x, y);
      if (node == null) {
        return _result(const <String, Object?>{
          'node': null,
          'path': <Object>[],
        });
      }
      final path = <GNode>[];
      for (GNode? current = node; current != null; current = current._parent) {
        path.add(current);
      }
      return _result(<String, Object?>{
        'node': _nodeSummary(node),
        'path': <Object>[
          for (var i = path.length - 1; i >= 0; --i) _nodeSummary(path[i]),
        ],
      });
    } on FormatException catch (error) {
      return _invalidParams(error.message);
    } on StateError catch (error) {
      return _notFound(error.message);
    } catch (error) {
      return _extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleSetSelection(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _requireStage(parameters['stageId']);
      final nodeId = parameters['nodeId'];
      final enabled = _parseBool(parameters, 'enabled', defaultValue: true);
      GNode? node;
      if (nodeId != null && nodeId.isNotEmpty) {
        node = _requireNode(nodeId);
        if (!identical(node._stage, stage)) {
          return _invalidParams('Selected node does not belong to the Stage.');
        }
      }
      final state = _selection[stage] ??= _GInspectorSelection();
      state
        ..node = node == null ? null : WeakReference<GNode>(node)
        ..enabled = enabled && node != null;
      stage.requestPaint();
      return _result(<String, Object?>{
        'selectedNodeId': node == null ? null : _idForObject(node),
        'enabled': state.enabled,
      });
    } on FormatException catch (error) {
      return _invalidParams(error.message);
    } on StateError catch (error) {
      return _notFound(error.message);
    } catch (error) {
      return _extensionError(error);
    }
  }

  List<GStage> _liveStages() {
    final result = <GStage>[];
    var write = 0;
    for (var i = 0; i < _stages.length; ++i) {
      final stage = _stages[i].target;
      if (stage == null || stage.isDisposed || !stage.isMounted) continue;
      result.add(stage);
      _stages[write++] = _stages[i];
    }
    if (write != _stages.length) _stages.length = write;
    return result;
  }

  String _idForStage(GStage stage) {
    final current = _stageIds[stage];
    if (current != null) return current;
    final id = 's${_nextStageId++}';
    _stageIds[stage] = id;
    _stageById[id] = WeakReference<GStage>(stage);
    return id;
  }

  String _idForObject(Object object) {
    final current = _objectIds[object];
    if (current != null) return current;
    final id = 'o${_nextObjectId++}';
    _objectIds[object] = id;
    _objectById[id] = WeakReference<Object>(object);
    if ((_nextObjectId & 0x1ff) == 0) _pruneObjectIds();
    return id;
  }

  void _pruneObjectIds() {
    _objectById.removeWhere((_, reference) {
      final object = reference.target;
      return object == null || _objectUnavailable(object);
    });
  }

  bool _objectUnavailable(Object object) => switch (object) {
    GNode(:final isDisposed) => isDisposed,
    GNodeCache(:final isDisposed) => isDisposed,
    _ => false,
  };

  GStage _requireStage(String? id) {
    if (id == null || id.isEmpty) {
      throw const FormatException('stageId is required.');
    }
    final stage = _stageById[id]?.target;
    if (stage == null || stage.isDisposed || !stage.isMounted) {
      _stageById.remove(id);
      throw StateError('Stage $id is no longer available.');
    }
    return stage;
  }

  Object _requireObject(String? id) {
    if (id == null || id.isEmpty) {
      throw const FormatException('objectId is required.');
    }
    final object = _objectById[id]?.target;
    if (object == null || _objectUnavailable(object)) {
      _objectById.remove(id);
      throw StateError('Object $id is no longer available.');
    }
    return object;
  }

  GNode _requireNode(String? id) {
    if (id == null || id.isEmpty) {
      throw const FormatException('nodeId is required.');
    }
    final object = _requireObject(id);
    if (object is! GNode) {
      throw StateError('Object $id is not a GNode.');
    }
    return object;
  }

  int _parseInt(
    Map<String, String> parameters,
    String key, {
    required int defaultValue,
  }) {
    final value = parameters[key];
    if (value == null || value.isEmpty) return defaultValue;
    final parsed = int.tryParse(value);
    if (parsed == null) throw FormatException('$key must be an integer.');
    return parsed;
  }

  double _parseDouble(Map<String, String> parameters, String key) {
    final value = parameters[key];
    if (value == null || value.isEmpty) {
      throw FormatException('$key is required.');
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('$key must be a finite number.');
    }
    return parsed;
  }

  bool _parseBool(
    Map<String, String> parameters,
    String key, {
    required bool defaultValue,
  }) {
    final value = parameters[key];
    if (value == null || value.isEmpty) return defaultValue;
    return switch (value) {
      'true' => true,
      'false' => false,
      _ => throw FormatException('$key must be true or false.'),
    };
  }

  Map<String, Object?> _stageSummary(GStage stage) => <String, Object?>{
    'id': _idForStage(stage),
    'root': _nodeSummary(stage.root),
    'mounted': stage.isMounted,
    'hosted': stage.isHosted,
    'attached': stage._rootAttached,
    'width': stage.width,
    'height': stage.height,
    'devicePixelRatio': stage.devicePixelRatio,
    'frame': stage.frame,
    'nodeCount': stage._nodeCount,
  };

  Map<String, Object?> _objectSummary(Object object) => <String, Object?>{
    'id': _idForObject(object),
    'kind': _objectKind(object),
    'type': object.runtimeType.toString(),
    'label': _objectLabel(object),
  };

  String _objectKind(Object object) => switch (object) {
    GNode() => 'node',
    GNodeCache() => 'cache',
    GFilter() => 'filter',
    _ => 'object',
  };

  String _objectLabel(Object object) => switch (object) {
    GNode(:final name) => name ?? object.runtimeType.toString(),
    GNodeCache() => 'Raster cache',
    GFilter() => object.runtimeType.toString(),
    _ => object.runtimeType.toString(),
  };

  Map<String, Object?> _nodeSummary(GNode node) => <String, Object?>{
    ..._objectSummary(node),
    'name': node.name,
    'childCount': node._children?.length ?? 0,
    'visible': node._visible,
    'active': node._active,
    'attached': node.isAttached,
  };

  Map<String, Object?> _inspectObject(Object object) => switch (object) {
    GNode node => _inspectNode(node),
    GNodeCache cache => _inspectCache(cache),
    GFilter filter => _inspectFilter(filter),
    _ => <String, Object?>{
      ..._objectSummary(object),
      'references': const <Object>[],
    },
  };

  Map<String, Object?>? _creationSource(GNode node) {
    final location = developer.CreationLocation.of(node);
    if (location == null) return null;
    return <String, Object?>{
      'kind': 'creation',
      'file': location.file,
      'line': location.line,
      'column': location.column,
      'name': location.name,
    };
  }

  Map<String, Object?> _inspectNode(GNode node) {
    final stage = node._stage;
    final localMatrixDirty = node._localMatrixDirty;
    final selfBoundsDirty = node._selfBoundsDirty;
    final localBoundsDirty = node._localBoundsDirty;

    final localMatrix = GMatrix2();
    node.copyLocalMatrixInto(localMatrix);
    final worldMatrix = GMatrix2();
    node.copyWorldMatrixInto(worldMatrix);

    final selfBounds = node._ensureSelfBounds();
    final localBounds = node._ensureLocalBounds();
    final effectBounds = node.getEffectBounds();
    final stageBounds = stage == null ? null : node.getBounds(stage.root);

    var effectiveVisible = true;
    var effectiveActive = true;
    var effectiveAlpha = 1.0;
    for (GNode? current = node; current != null; current = current._parent) {
      effectiveVisible = effectiveVisible && current._visible;
      effectiveActive = effectiveActive && current._active;
      effectiveAlpha *= current._alpha;
    }

    final composite = node._composite;
    final cache = node._cache;
    final focus = _maybeNodeFocus(node);
    final focusManager = stage == null ? null : _gStageFocus[stage];
    final pointer = node._pointer;
    final filters = composite?.filters;
    final source = _creationSource(node);

    return <String, Object?>{
      ..._objectSummary(node),
      'name': node.name,
      'source': source,
      'parentId': node._parent == null ? null : _idForObject(node._parent!),
      'stageId': stage == null ? null : _idForStage(stage),
      'childCount': node._children?.length ?? 0,
      'references': <Object>[
        if (composite?.mask case final mask?)
          <String, Object?>{'relation': 'mask', ..._objectSummary(mask)},
        if (cache != null)
          <String, Object?>{'relation': 'cache', ..._objectSummary(cache)},
        if (filters != null)
          for (var i = 0; i < filters.length; ++i)
            <String, Object?>{
              'relation': 'filter',
              'index': i,
              ..._objectSummary(filters[i]),
            },
      ],
      'lifecycle': <String, Object?>{
        'disposed': node.isDisposed,
        'attached': node.isAttached,
        'visible': node._visible,
        'effectiveVisible': effectiveVisible,
        'active': node._active,
        'effectiveActive': effectiveActive,
        'updatesEnabled': node.updatesEnabled,
      },
      'transform': <String, Object?>{
        'x': node._x,
        'y': node._y,
        'scaleX': node._scaleX,
        'scaleY': node._scaleY,
        'rotation': node._rotation,
        'skewX': node._skewX,
        'skewY': node._skewY,
        'pivotX': node._pivotX,
        'pivotY': node._pivotY,
        'localMatrix': _matrixJson(localMatrix),
        'worldMatrix': _matrixJson(worldMatrix),
        'localVersion': node._localTransformVersion,
        'worldVersion': node._worldTransformVersion,
        'dirtyBeforeInspection': localMatrixDirty,
      },
      'bounds': <String, Object?>{
        'self': _boundsJson(selfBounds),
        'local': _boundsJson(localBounds),
        'stage': stageBounds == null ? null : _boundsJson(stageBounds),
        'world': stageBounds == null ? null : _boundsJson(stageBounds),
        'effectLocal': _boundsJson(effectBounds),
        'selfDirtyBeforeInspection': selfBoundsDirty,
        'localDirtyBeforeInspection': localBoundsDirty,
      },
      'render': <String, Object?>{
        'paintSelf': node._paintSelf,
        'alpha': node._alpha,
        'effectiveAlpha': effectiveAlpha,
        'compositeMode': node.compositeMode.name,
        'blendMode': node.blendMode.name,
        'clip': composite?.clip?.runtimeType.toString(),
        'maskId': composite?.mask == null
            ? null
            : _idForObject(composite!.mask!),
        'maskMode': composite?.maskMode.name,
        'filters': <Object>[
          if (filters != null)
            for (final filter in filters) _objectSummary(filter),
        ],
        'hasColorTransform': composite?.colorTransform != null,
      },
      'cache': cache == null
          ? const <String, Object?>{'allocated': false}
          : <String, Object?>{
              'allocated': true,
              'objectId': _idForObject(cache),
              'enabled': cache._enabled,
              'scale': cache._scale,
              'ready': cache.isReady,
              'dirty': cache.isDirty,
              'building': cache.isBuilding,
              'rasterScale': cache._rasterScale,
              'captures': cache._captures,
              'pixelWidth': cache.pixelWidth,
              'pixelHeight': cache.pixelHeight,
              'retainedBytes': cache._retainedBytes,
              'contentVersion': cache._contentVersion,
              'capturedVersion': cache._capturedVersion,
            },
      'focus': focus == null
          ? <String, Object?>{
              'allocated': false,
              'focusable': false,
              'focused': identical(focusManager?.focusedNode, node),
              'focusWithin': _hasFocusWithin(focusManager?.focusedNode, node),
            }
          : <String, Object?>{
              'allocated': true,
              'focusable': focus._effectiveFocusable,
              'registered': focus._registered,
              'skipTraversal': focus._skipTraversal,
              'focusOnPointer': focus._focusOnPointer,
              'portalAvailable': focus._portalAvailable,
              'focused': identical(focusManager?.focusedNode, node),
              'focusWithin': _hasFocusWithin(focusManager?.focusedNode, node),
              'hasActionListeners': focus._action?.hasListeners ?? false,
              'neighbors': <String, Object?>{
                'next': _optionalObjectId(focus.next),
                'previous': _optionalObjectId(focus.previous),
                'left': _optionalObjectId(focus.left),
                'right': _optionalObjectId(focus.right),
                'up': _optionalObjectId(focus.up),
                'down': _optionalObjectId(focus.down),
              },
            },
      'pointer': pointer == null
          ? const <String, Object?>{'allocated': false, 'interested': false}
          : <String, Object?>{
              'allocated': true,
              'enabled': pointer._enabled,
              'children': pointer._children,
              'interested': pointer._hasInterest,
              'hoverInterested': pointer._hasHoverInterest,
              'hitArea': pointer._hitArea?.runtimeType.toString(),
              'cursor': pointer._cursor?.runtimeType.toString(),
            },
    };
  }

  Map<String, Object?> _inspectCache(GNodeCache cache) => <String, Object?>{
    ..._objectSummary(cache),
    'references': <Object>[
      <String, Object?>{'relation': 'owner', ..._objectSummary(cache._node)},
    ],
    'ownerId': _idForObject(cache._node),
    'enabled': cache._enabled,
    'scale': cache._scale,
    'ready': cache.isReady,
    'dirty': cache.isDirty,
    'building': cache.isBuilding,
    'rasterScale': cache._rasterScale,
    'captures': cache._captures,
    'pixelWidth': cache.pixelWidth,
    'pixelHeight': cache.pixelHeight,
    'retainedBytes': cache._retainedBytes,
    'contentVersion': cache._contentVersion,
    'capturedVersion': cache._capturedVersion,
  };

  Map<String, Object?> _inspectFilter(GFilter filter) {
    final owner = filter.owner;
    return <String, Object?>{
      ..._objectSummary(filter),
      'references': <Object>[
        if (owner != null)
          <String, Object?>{'relation': 'owner', ..._objectSummary(owner)},
      ],
      'ownerId': owner == null ? null : _idForObject(owner),
      'version': filter._version,
      'properties': switch (filter) {
        GBlurFilter(:final blurX, :final blurY) => <String, Object?>{
          'blurX': blurX,
          'blurY': blurY,
        },
        _ => const <String, Object?>{},
      },
    };
  }

  String? _optionalObjectId(Object? object) => object == null
      ? null
      : switch (object) {
          GNode(:final isDisposed) when isDisposed => null,
          GNodeCache(:final isDisposed) when isDisposed => null,
          _ => _idForObject(object),
        };

  bool _hasFocusWithin(GNode? focused, GNode candidate) {
    for (var current = focused; current != null; current = current._parent) {
      if (identical(current, candidate)) return true;
    }
    return false;
  }

  Map<String, Object?> _matrixJson(GMatrix2 matrix) => <String, Object?>{
    'a': matrix.a,
    'b': matrix.b,
    'c': matrix.c,
    'd': matrix.d,
    'tx': matrix.tx,
    'ty': matrix.ty,
  };

  Map<String, Object?> _boundsJson(GBounds bounds) {
    if (bounds.isEmpty) return const <String, Object?>{'empty': true};
    return <String, Object?>{
      'empty': false,
      'x': bounds.x1,
      'y': bounds.y1,
      'width': bounds.width,
      'height': bounds.height,
      'x2': bounds.x2,
      'y2': bounds.y2,
    };
  }

  void paintOverlay(Canvas canvas, GStage stage) {
    assert(!kReleaseMode);
    final selection = _selection[stage];
    if (selection == null || !selection.enabled) return;
    final node = selection.node?.target;
    if (node == null ||
        node.isDisposed ||
        !node.isAttached ||
        !identical(node._stage, stage)) {
      selection
        ..node = null
        ..enabled = false;
      return;
    }

    final bounds = node.getBounds(stage.root, selection.bounds);
    node.localToGlobalInto(0.0, 0.0, selection.origin);
    node.localToGlobalInto(node._pivotX, node._pivotY, selection.pivot);

    final views = _renderViewsOf(stage)?._items;
    if (views == null || views.isEmpty) {
      if (!bounds.isEmpty) {
        canvas.drawRect(
          ui.Rect.fromLTRB(bounds.x1, bounds.y1, bounds.x2, bounds.y2),
          selection.boundsPaint,
        );
      }
      canvas.drawCircle(
        ui.Offset(selection.origin.x, selection.origin.y),
        4.0,
        selection.originPaint,
      );
      canvas.drawCircle(
        ui.Offset(selection.pivot.x, selection.pivot.y),
        4.0,
        selection.pivotPaint,
      );
      return;
    }

    for (var i = 0; i < views.length; ++i) {
      final view = views[i];
      if (!_nodeVisibleInRenderView(node, view)) continue;
      final viewport = view.viewport;
      canvas.save();
      try {
        canvas.clipRect(
          ui.Rect.fromLTWH(viewport.x, viewport.y, viewport.w, viewport.h),
        );
        if (!bounds.isEmpty) {
          view.worldToStageInto(bounds.x1, bounds.y1, selection.corner0);
          view.worldToStageInto(bounds.x2, bounds.y1, selection.corner1);
          view.worldToStageInto(bounds.x2, bounds.y2, selection.corner2);
          view.worldToStageInto(bounds.x1, bounds.y2, selection.corner3);
          final path = selection.projectedBounds
            ..reset()
            ..moveTo(selection.corner0.x, selection.corner0.y)
            ..lineTo(selection.corner1.x, selection.corner1.y)
            ..lineTo(selection.corner2.x, selection.corner2.y)
            ..lineTo(selection.corner3.x, selection.corner3.y)
            ..close();
          canvas.drawPath(path, selection.boundsPaint);
        }

        view.worldToStageInto(
          selection.origin.x,
          selection.origin.y,
          selection.projectedOrigin,
        );
        view.worldToStageInto(
          selection.pivot.x,
          selection.pivot.y,
          selection.projectedPivot,
        );
        canvas.drawCircle(
          ui.Offset(selection.projectedOrigin.x, selection.projectedOrigin.y),
          4.0,
          selection.originPaint,
        );
        canvas.drawCircle(
          ui.Offset(selection.projectedPivot.x, selection.projectedPivot.y),
          4.0,
          selection.pivotPaint,
        );
      } finally {
        canvas.restore();
      }
    }
  }

  developer.ServiceExtensionResponse _result(Object? value) =>
      developer.ServiceExtensionResponse.result(jsonEncode(value));

  developer.ServiceExtensionResponse _invalidParams(String message) =>
      developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        jsonEncode(<String, Object?>{'message': message}),
      );

  developer.ServiceExtensionResponse _notFound(String message) =>
      developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        jsonEncode(<String, Object?>{'message': message, 'kind': 'notFound'}),
      );

  developer.ServiceExtensionResponse _extensionError(Object error) =>
      developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        jsonEncode(<String, Object?>{
          'message': 'GraphX inspector request failed.',
          'error': error.toString(),
        }),
      );
}

final class _GInspectorSelection {
  WeakReference<GNode>? node;
  bool enabled = false;

  final GBounds bounds = GBounds.empty();
  final GPoint origin = GPoint();
  final GPoint pivot = GPoint();
  final GPoint corner0 = GPoint();
  final GPoint corner1 = GPoint();
  final GPoint corner2 = GPoint();
  final GPoint corner3 = GPoint();
  final GPoint projectedOrigin = GPoint();
  final GPoint projectedPivot = GPoint();
  final ui.Path projectedBounds = ui.Path();
  final ui.Paint boundsPaint = ui.Paint()
    ..color = const ui.Color(0xff00bcd4)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final ui.Paint originPaint = ui.Paint()
    ..color = const ui.Color(0xffffc107)
    ..style = ui.PaintingStyle.fill;
  final ui.Paint pivotPaint = ui.Paint()
    ..color = const ui.Color(0xffe91e63)
    ..style = ui.PaintingStyle.fill;
}
