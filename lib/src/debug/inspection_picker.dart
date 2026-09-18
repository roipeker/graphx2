part of 'package:graphx/src/graphx_impl.dart';

final _GInspectorPickerRuntime _gInspectorPickerRuntime =
    _GInspectorPickerRuntime();

/// Debug-only scene picking owned outside the retained scene.
///
/// The preferred path inserts a temporary Flutter [OverlayEntry] exactly over
/// the hosted GraphXView. That entry owns pointer input while inspection is
/// armed, so a selection click never enters GraphX's normal pointer/gesture
/// pipeline. If the host has no Overlay ancestor, the runtime falls back to the
/// older observe-only Stage pointer path and DevTools can still confirm the
/// candidate explicitly.
final class _GInspectorPickerRuntime {
  static const _prefix = 'ext.graphx.inspector';

  final Expando<_GInspectorPickState> _states = Expando<_GInspectorPickState>(
    'graphx.inspector.pickState',
  );

  bool _extensionsRegistered = false;
  WeakReference<GStage>? _activeStage;

  void registerStage(GStage stage) {
    assert(!kReleaseMode);
    _ensureExtensionsRegistered();
    _gInspectorDiagnosticsRuntime.ensureRegistered();
  }

  void unregisterStage(GStage stage) {
    assert(!kReleaseMode);
    final state = _states[stage];
    if (state == null) return;
    if (state.enabled) {
      _disable(stage, state, restoreSelection: true);
    } else {
      _removeInteraction(state);
    }
    _states[stage] = null;
    if (identical(_activeStage?.target, stage)) _activeStage = null;
  }

  void _ensureExtensionsRegistered() {
    if (_extensionsRegistered) return;
    _extensionsRegistered = true;
    developer.registerExtension('$_prefix.setPickMode', _handleSetPickMode);
    developer.registerExtension('$_prefix.getPickState', _handleGetPickState);
    developer.registerExtension('$_prefix.commitPick', _handleCommitPick);
  }

  Future<developer.ServiceExtensionResponse> _handleSetPickMode(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _gInspectorRuntime._requireStage(parameters['stageId']);
      final enabled = _gInspectorRuntime._parseBool(
        parameters,
        'enabled',
        defaultValue: true,
      );
      final state = _states[stage] ??= _GInspectorPickState();
      if (enabled) {
        _enable(stage, state);
      } else {
        _disable(stage, state, restoreSelection: true);
      }
      return _gInspectorRuntime._result(<String, Object?>{
        'state': _stateJson(stage, state),
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleGetPickState(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _gInspectorRuntime._requireStage(parameters['stageId']);
      final state = _states[stage] ??= _GInspectorPickState();
      return _gInspectorRuntime._result(<String, Object?>{
        'state': _stateJson(stage, state),
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleCommitPick(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _gInspectorRuntime._requireStage(parameters['stageId']);
      final state = _states[stage] ??= _GInspectorPickState();
      if (!state.enabled) {
        // A host-intercepted click may already have committed and exited pick
        // mode before an older DevTools client sends its explicit confirm.
        final committed = state.committed?.target;
        if (committed != null &&
            !committed.isDisposed &&
            committed.isAttached) {
          return _commitResult(stage, state, committed);
        }
        return _gInspectorRuntime._invalidParams(
          'Scene picker is not enabled.',
        );
      }
      final candidate = state.candidate?.target;
      if (candidate == null || candidate.isDisposed || !candidate.isAttached) {
        _disable(stage, state, restoreSelection: true);
        return _gInspectorRuntime._result(<String, Object?>{
          'node': null,
          'path': const <Object>[],
          'state': _stateJson(stage, state),
        });
      }

      _commit(stage, state, candidate);
      return _commitResult(stage, state, candidate);
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  developer.ServiceExtensionResponse _commitResult(
    GStage stage,
    _GInspectorPickState state,
    GNode node,
  ) {
    final path = <GNode>[];
    for (GNode? current = node; current != null; current = current._parent) {
      path.add(current);
    }
    return _gInspectorRuntime._result(<String, Object?>{
      'node': _gInspectorRuntime._nodeSummary(node),
      'path': <Object>[
        for (var i = path.length - 1; i >= 0; --i)
          _gInspectorRuntime._nodeSummary(path[i]),
      ],
      'state': _stateJson(stage, state),
    });
  }

  void _enable(GStage stage, _GInspectorPickState state) {
    if (state.enabled) return;

    final active = _activeStage?.target;
    if (active != null && !identical(active, stage)) {
      final activeState = _states[active];
      if (activeState != null && activeState.enabled) {
        _disable(active, activeState, restoreSelection: true);
      }
    }
    _activeStage = WeakReference<GStage>(stage);

    final existing = _gInspectorRuntime._selection[stage];
    state
      ..enabled = true
      ..candidate = null
      ..committed = null
      ..previousNode = existing?.node
      ..previousHighlight = existing?.enabled ?? false
      ..hostIntercept = false;
    state.revision++;

    state.hostIntercept = _installHostOverlay(stage, state);
    if (!state.hostIntercept) _installPointerFallback(stage, state);
    _installEscapeHandler(stage, state);
  }

  bool _installHostOverlay(GStage stage, _GInspectorPickState state) {
    final context = stage._flutterContext;
    if (context == null || !context.mounted) return false;
    final target = context.findRenderObject();
    if (target is! RenderBox || !target.attached || !target.hasSize)
      return false;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;
    final overlayTarget = overlay.context.findRenderObject();
    if (overlayTarget is! RenderBox ||
        !overlayTarget.attached ||
        !overlayTarget.hasSize) {
      return false;
    }

    final globalTopLeft = target.localToGlobal(Offset.zero);
    final topLeft = overlayTarget.globalToLocal(globalTopLeft);
    final size = target.size;
    if (size.isEmpty) return false;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: topLeft.dx,
        top: topLeft.dy,
        width: size.width,
        height: size.height,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerHover: (event) => _updateCandidate(
            stage,
            state,
            event.localPosition.dx,
            event.localPosition.dy,
          ),
          onPointerMove: (event) => _updateCandidate(
            stage,
            state,
            event.localPosition.dx,
            event.localPosition.dy,
          ),
          onPointerDown: (event) {
            _updateCandidate(
              stage,
              state,
              event.localPosition.dx,
              event.localPosition.dy,
            );
            final candidate = state.candidate?.target;
            if (candidate != null &&
                !candidate.isDisposed &&
                candidate.isAttached) {
              _commit(stage, state, candidate);
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  left: 10,
                  top: 10,
                  child: IgnorePointer(child: _buildHostBadge(state)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    state.overlayEntry = entry;
    overlay.insert(entry);
    return true;
  }

  Widget _buildHostBadge(_GInspectorPickState state) {
    final candidate = state.candidate?.target;
    final label = candidate == null
        ? 'Click a GraphX object · Esc to cancel'
        : '${candidate.name ?? candidate.runtimeType} · click to select';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xee111318),
        border: Border.all(color: const Color(0x66c7ff2e)),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xffc7ff2e),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'GRAPHX INSPECT',
              style: TextStyle(
                color: Color(0xffc7ff2e),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xffe8e8e8),
                fontSize: 11,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _installPointerFallback(GStage stage, _GInspectorPickState state) {
    void update(GPointerEvent event) =>
        _updateCandidate(stage, state, event.x, event.y);

    state
      ..hoverSubscription = stage.pointer.onHover.add(update)
      ..moveSubscription = stage.pointer.onMove.add(update);

    if (stage.pointer.isInside) {
      _updateCandidate(stage, state, stage.pointer.x, stage.pointer.y);
    }
  }

  void _installEscapeHandler(GStage stage, _GInspectorPickState state) {
    bool handler(KeyEvent event) {
      if (!state.enabled ||
          event is! KeyDownEvent ||
          event.logicalKey != LogicalKeyboardKey.escape) {
        return false;
      }
      _disable(stage, state, restoreSelection: true);
      return true;
    }

    state.keyHandler = handler;
    HardwareKeyboard.instance.addHandler(handler);
  }

  void _disable(
    GStage stage,
    _GInspectorPickState state, {
    required bool restoreSelection,
  }) {
    if (!state.enabled) return;
    state.enabled = false;
    _removeInteraction(state);
    if (restoreSelection) {
      final previous = state.previousNode?.target;
      final overlay = _gInspectorRuntime._selection[stage] ??=
          _GInspectorSelection();
      overlay
        ..node = previous == null ? null : WeakReference<GNode>(previous)
        ..enabled = state.previousHighlight && previous != null;
      stage.requestPaint();
    }
    state
      ..previousNode = null
      ..previousHighlight = false;
    state.revision++;
    if (identical(_activeStage?.target, stage)) _activeStage = null;
  }

  void _commit(GStage stage, _GInspectorPickState state, GNode candidate) {
    state.committed = WeakReference<GNode>(candidate);
    state.revision++;
    _disable(stage, state, restoreSelection: false);
    _setOverlay(stage, candidate);
  }

  void _removeInteraction(_GInspectorPickState state) {
    state.hoverSubscription?.cancel();
    state.moveSubscription?.cancel();
    state
      ..hoverSubscription = null
      ..moveSubscription = null;

    final entry = state.overlayEntry;
    state.overlayEntry = null;
    if (entry?.mounted ?? false) entry!.remove();

    final handler = state.keyHandler;
    state.keyHandler = null;
    if (handler != null) HardwareKeyboard.instance.removeHandler(handler);
  }

  void _updateCandidate(
    GStage stage,
    _GInspectorPickState state,
    double x,
    double y,
  ) {
    if (!state.enabled || stage.isDisposed || !stage.isMounted) return;
    final candidate = stage.hitTest(x, y);
    if (identical(state.candidate?.target, candidate) &&
        state.x == x &&
        state.y == y) {
      return;
    }
    state
      ..x = x
      ..y = y
      ..candidate = candidate == null ? null : WeakReference<GNode>(candidate);
    state.revision++;
    state.overlayEntry?.markNeedsBuild();
    _setOverlay(stage, candidate);
  }

  void _setOverlay(GStage stage, GNode? node) {
    final overlay = _gInspectorRuntime._selection[stage] ??=
        _GInspectorSelection();
    overlay
      ..node = node == null ? null : WeakReference<GNode>(node)
      ..enabled = node != null;
    stage.requestPaint();
  }

  Map<String, Object?> _stateJson(GStage stage, _GInspectorPickState state) {
    final candidate = state.candidate?.target;
    final committed = state.committed?.target;
    return <String, Object?>{
      'stageId': _gInspectorRuntime._idForStage(stage),
      'enabled': state.enabled,
      'hostIntercept': state.hostIntercept,
      'revision': state.revision,
      'x': state.x,
      'y': state.y,
      'candidate': candidate == null || candidate.isDisposed
          ? null
          : _gInspectorRuntime._nodeSummary(candidate),
      'committed': committed == null || committed.isDisposed
          ? null
          : _gInspectorRuntime._nodeSummary(committed),
    };
  }
}

final class _GInspectorPickState {
  bool enabled = false;
  bool hostIntercept = false;
  int revision = 0;
  double x = 0.0;
  double y = 0.0;
  WeakReference<GNode>? candidate;
  WeakReference<GNode>? committed;
  WeakReference<GNode>? previousNode;
  bool previousHighlight = false;
  GSignalSubscription? hoverSubscription;
  GSignalSubscription? moveSubscription;
  OverlayEntry? overlayEntry;
  bool Function(KeyEvent)? keyHandler;
}
