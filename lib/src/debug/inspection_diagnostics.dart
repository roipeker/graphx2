part of 'package:graphx/graphx.dart';

final _GInspectorDiagnosticsRuntime _gInspectorDiagnosticsRuntime =
    _GInspectorDiagnosticsRuntime();

/// On-demand explanations for common retained-scene debugging questions.
///
/// This deliberately does not subscribe to mutations or retain per-node state.
/// Facts are derived from the same private state used by rendering/input when a
/// tooling client explicitly asks for them.
final class _GInspectorDiagnosticsRuntime {
  static const _prefix = 'ext.graphx.inspector';
  bool _registered = false;

  void ensureRegistered() {
    assert(!kReleaseMode);
    if (_registered) return;
    _registered = true;
    developer.registerExtension('$_prefix.diagnoseNode', _handleDiagnoseNode);
  }

  Future<developer.ServiceExtensionResponse> _handleDiagnoseNode(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final node = _gInspectorRuntime._requireNode(parameters['nodeId']);
      return _gInspectorRuntime._result(<String, Object?>{
        'diagnostics': _diagnoseNode(node),
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Map<String, Object?> _diagnoseNode(GNode node) {
    final stage = node._stage;
    final pathLeafToRoot = <GNode>[];
    for (GNode? current = node; current != null; current = current._parent) {
      pathLeafToRoot.add(current);
    }
    final path = pathLeafToRoot.reversed;

    final renderBlockers = <Object>[];
    final pointerBlockers = <Object>[];
    var effectiveAlpha = 1.0;
    var pointerInterest = false;

    if (!node.isAttached || stage == null) {
      _addBlocker(
        renderBlockers,
        'scene.detached',
        'Node is not attached to a mounted Stage.',
        node,
      );
      _addBlocker(
        pointerBlockers,
        'scene.detached',
        'Node is not attached to a mounted Stage.',
        node,
      );
    }

    for (final current in path) {
      effectiveAlpha *= current._alpha;
      if (!current._active) {
        _addBlocker(
          renderBlockers,
          'render.inactive',
          identical(current, node)
              ? 'Node is inactive.'
              : 'Ancestor ${_label(current)} is inactive.',
          current,
        );
        _addBlocker(
          pointerBlockers,
          'pointer.inactive',
          identical(current, node)
              ? 'Node is inactive.'
              : 'Ancestor ${_label(current)} is inactive.',
          current,
        );
      }
      if (!current._visible) {
        _addBlocker(
          renderBlockers,
          'render.hidden',
          identical(current, node)
              ? 'Node is hidden.'
              : 'Ancestor ${_label(current)} is hidden.',
          current,
        );
        _addBlocker(
          pointerBlockers,
          'pointer.hidden',
          identical(current, node)
              ? 'Node is hidden.'
              : 'Ancestor ${_label(current)} is hidden.',
          current,
        );
      }

      final pointer = current._pointer;
      pointerInterest = pointerInterest || (pointer?._hasInterest ?? false);
      if (pointer != null && !pointer._enabled) {
        _addBlocker(
          pointerBlockers,
          'pointer.disabled',
          identical(current, node)
              ? 'Pointer handling is disabled on this node.'
              : 'Ancestor ${_label(current)} disables pointer handling.',
          current,
        );
      }
      if (!identical(current, node) && pointer != null && !pointer._children) {
        _addBlocker(
          pointerBlockers,
          'pointer.children-disabled',
          'Ancestor ${_label(current)} does not route pointer hits to children.',
          current,
        );
      }

      if (current.hasLocalTransform) {
        final matrix = current.localMatrix;
        final determinant = matrix.a * matrix.d - matrix.b * matrix.c;
        if (!determinant.isFinite || determinant == 0.0) {
          _addBlocker(
            pointerBlockers,
            'pointer.singular-transform',
            'Transform on ${_label(current)} is not invertible for hit testing.',
            current,
          );
        }
      }
    }

    if (effectiveAlpha <= 0.0) {
      _addBlocker(
        renderBlockers,
        'render.zero-alpha',
        'Effective alpha is zero, so the renderer stops before painting this subtree.',
        node,
      );
    }

    if (stage != null && !stage.input.enabled) {
      _addBlocker(
        pointerBlockers,
        'pointer.stage-input-disabled',
        'Stage input is disabled.',
        node,
      );
    }

    final focus = _maybeNodeFocus(node);
    final focusBlockers = <Object>[];
    if (focus != null) {
      if (stage == null || !node.isAttached) {
        _addBlocker(
          focusBlockers,
          'focus.detached',
          'Focus requires an attached Stage node.',
          node,
        );
      }
      if (!focus._effectiveFocusable) {
        _addBlocker(
          focusBlockers,
          'focus.not-focusable',
          'The node is not currently focusable.',
          node,
        );
      }
    }

    return <String, Object?>{
      'nodeId': _gInspectorRuntime._idForObject(node),
      'render': <String, Object?>{
        'participates': true,
        'eligible': renderBlockers.isEmpty,
        'paintSelf': node._paintSelf,
        'effectiveAlpha': effectiveAlpha,
        'blockers': renderBlockers,
        'viewport': _viewportDiagnostic(node, stage),
      },
      // A domain with no participation is normal retained-scene state, not a
      // blocker. Omitting it keeps older clients from rendering a false error;
      // newer clients may explicitly present non-participation as neutral.
      'pointer': pointerInterest
          ? <String, Object?>{
              'participates': true,
              'eligible': pointerBlockers.isEmpty,
              'hasInterestPath': true,
              'blockers': pointerBlockers,
            }
          : null,
      'focus': focus != null
          ? <String, Object?>{
              'participates': true,
              'eligible': focusBlockers.isEmpty,
              'blockers': focusBlockers,
            }
          : null,
    };
  }

  Map<String, Object?>? _viewportDiagnostic(GNode node, GStage? stage) {
    if (stage == null || node._parent is! GViewportGroup) return null;
    final group = node._parent! as GViewportGroup;
    if (!group.cullingEnabled) {
      return <String, Object?>{
        'groupId': _gInspectorRuntime._idForObject(group),
        'groupLabel': _label(group),
        'cullingEnabled': false,
      };
    }

    final bounds = node.getBounds(stage.root);
    final outside =
        bounds.isEmpty ||
        bounds.x2 <= 0.0 ||
        bounds.y2 <= 0.0 ||
        bounds.x1 >= stage.width ||
        bounds.y1 >= stage.height;
    return <String, Object?>{
      'groupId': _gInspectorRuntime._idForObject(group),
      'groupLabel': _label(group),
      'cullingEnabled': true,
      'outsideStageViewport': outside,
      'note': outside
          ? 'Direct child bounds are outside the Stage viewport; this viewport group can cull the subtree.'
          : 'Direct child bounds intersect the Stage viewport. Active canvas clips may constrain the renderer further.',
    };
  }

  void _addBlocker(
    List<Object> target,
    String code,
    String message,
    GNode owner,
  ) {
    target.add(<String, Object?>{
      'code': code,
      'message': message,
      'ownerId': _gInspectorRuntime._idForObject(owner),
      'ownerLabel': _label(owner),
    });
  }

  String _label(GNode node) => node.name ?? node.runtimeType.toString();
}
