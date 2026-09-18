// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

final _GInspectorActivityRuntime _gInspectorActivityRuntime = _GInspectorActivityRuntime();

/// Opt-in, bounded temporal evidence for tooling.
///
/// No state or input subscriptions are allocated for a Stage until a tooling
/// client explicitly enables capture. v1 deliberately records low-frequency
/// pointer and keyboard transitions; move/hover traffic is excluded to keep
/// evidence compact and avoid turning inspection into a tracing system.
final class _GInspectorActivityRuntime {
  static const _prefix = 'ext.graphx.inspector';
  static const _defaultCapacity = 256;
  static const _maxCapacity = 4096;
  static const _defaultReadLimit = 200;
  static const _maxReadLimit = 1000;

  final Expando<_GInspectorActivityState> _states = Expando<_GInspectorActivityState>(
    'graphx.inspector.activity',
  );
  bool _registered = false;

  void registerStage(GStage stage) {
    assert(!kReleaseMode);
    _ensureRegistered();
  }

  void unregisterStage(GStage stage) {
    assert(!kReleaseMode);
    _states[stage]?.stop();
    _states[stage] = null;
  }

  void _ensureRegistered() {
    if (_registered) return;
    _registered = true;
    developer.registerExtension(
      '$_prefix.setActivityCapture',
      _handleSetActivityCapture,
    );
    developer.registerExtension('$_prefix.getActivity', _handleGetActivity);
  }

  Future<developer.ServiceExtensionResponse> _handleSetActivityCapture(
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
      final clear = _gInspectorRuntime._parseBool(
        parameters,
        'clear',
        defaultValue: enabled,
      );
      final requestedCapacity = _gInspectorRuntime._parseInt(
        parameters,
        'capacity',
        defaultValue: _defaultCapacity,
      );
      if (requestedCapacity <= 0) {
        return _gInspectorRuntime._invalidParams('capacity must be > 0.');
      }
      final capacity = math.min(requestedCapacity, _maxCapacity);
      var state = _states[stage];
      if (enabled && state == null) {
        state = _GInspectorActivityState(capacity);
        _states[stage] = state;
      }
      if (state != null) {
        state.capacity = capacity;
        if (clear) state.clear();
        state.trim();
        if (enabled) {
          state.start(stage, this);
        } else {
          state.stop();
        }
      }
      return _gInspectorRuntime._result(<String, Object?>{
        'activity': _stateJson(stage, state),
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleGetActivity(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _gInspectorRuntime._requireStage(parameters['stageId']);
      final after = _gInspectorRuntime._parseInt(
        parameters,
        'after',
        defaultValue: 0,
      );
      final requestedLimit = _gInspectorRuntime._parseInt(
        parameters,
        'limit',
        defaultValue: _defaultReadLimit,
      );
      if (after < 0 || requestedLimit <= 0) {
        return _gInspectorRuntime._invalidParams(
          'after must be >= 0 and limit must be > 0.',
        );
      }
      final limit = math.min(requestedLimit, _maxReadLimit);
      final state = _states[stage];
      final events = <Object>[];
      if (state != null) {
        for (final event in state.events) {
          if (event.sequence <= after) continue;
          events.add(event.toJson());
          if (events.length >= limit) break;
        }
      }
      return _gInspectorRuntime._result(<String, Object?>{
        'activity': _stateJson(stage, state),
        'after': after,
        'limit': limit,
        'events': events,
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Map<String, Object?> _stateJson(
    GStage stage,
    _GInspectorActivityState? state,
  ) => <String, Object?>{
    'stageId': _gInspectorRuntime._idForStage(stage),
    'enabled': state?.enabled ?? false,
    'capacity': state?.capacity ?? 0,
    'retained': state?.events.length ?? 0,
    'dropped': state?.dropped ?? 0,
    'lastSequence': state?.lastSequence ?? 0,
  };

  void recordPointer(
    GStage stage,
    _GInspectorActivityState state,
    String type,
    GPointerEvent event,
  ) {
    if (!state.enabled) return;
    final hitTarget = _resolvePointerHit(stage, event.x, event.y);
    final focused = _gStageFocus[stage]?.focusedNode;
    state.add(
      _GInspectorActivityEvent(
        sequence: state.nextSequence(),
        frame: stage.frame,
        elapsed: stage.elapsed,
        type: 'pointer.$type',
        data: <String, Object?>{
          'pointer': event.pointer,
          'kind': event.kind.name,
          'x': event.x,
          'y': event.y,
          'button': event.button,
          'buttons': event.buttons,
          if (event.isScroll) ...<String, Object?>{
            'scrollX': event.scrollX,
            'scrollY': event.scrollY,
            'scrollSource': event.scrollSource?.name,
          },
          'hitTargetId': hitTarget == null ? null : _gInspectorRuntime._idForObject(hitTarget),
          'hitTargetLabel': hitTarget?.name ?? hitTarget?.runtimeType.toString(),
          ..._focusJson(focused),
        },
      ),
    );
  }

  void recordKey(
    GStage stage,
    _GInspectorActivityState state,
    GKeyEvent event,
  ) {
    if (!state.enabled) return;
    final focused = _gStageFocus[stage]?.focusedNode;
    state.add(
      _GInspectorActivityEvent(
        sequence: state.nextSequence(),
        frame: stage.frame,
        elapsed: stage.elapsed,
        type: 'key.${event.type.name}',
        data: <String, Object?>{
          'logicalKey': event.logicalKey.keyId,
          'logicalKeyLabel': event.logicalKey.debugName ?? event.logicalKey.keyLabel,
          'physicalKey': event.physicalKey.usbHidUsage,
          'physicalKeyLabel': event.physicalKey.debugName,
          'character': event.character,
          ..._focusJson(focused),
        },
      ),
    );
  }

  Map<String, Object?> _focusJson(GNode? focused) => <String, Object?>{
    'focusedNodeId': focused == null ? null : _gInspectorRuntime._idForObject(focused),
    'focusedNodeLabel': focused?.name ?? focused?.runtimeType.toString(),
  };
}

final class _GInspectorActivityState {
  _GInspectorActivityState(this.capacity);

  int capacity;
  int dropped = 0;
  int _sequence = 0;
  List<GSignalSubscription>? _subscriptions;
  final List<_GInspectorActivityEvent> events = <_GInspectorActivityEvent>[];

  bool get enabled => _subscriptions != null;
  int get lastSequence => _sequence;

  int nextSequence() => ++_sequence;

  void start(GStage stage, _GInspectorActivityRuntime runtime) {
    if (enabled) return;
    final pointer = stage.pointer;
    final keyboard = stage.input.keyboard;
    _subscriptions = <GSignalSubscription>[
      pointer.onDown.add(
        (event) => runtime.recordPointer(stage, this, 'down', event),
      ),
      pointer.onUp.add(
        (event) => runtime.recordPointer(stage, this, 'up', event),
      ),
      pointer.onCancel.add(
        (event) => runtime.recordPointer(stage, this, 'cancel', event),
      ),
      pointer.onScroll.add(
        (event) => runtime.recordPointer(stage, this, 'scroll', event),
      ),
      keyboard.onDown.add((event) => runtime.recordKey(stage, this, event)),
      keyboard.onRepeat.add((event) => runtime.recordKey(stage, this, event)),
      keyboard.onUp.add((event) => runtime.recordKey(stage, this, event)),
    ];
  }

  void stop() {
    final subscriptions = _subscriptions;
    if (subscriptions == null) return;
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    _subscriptions = null;
  }

  void add(_GInspectorActivityEvent event) {
    events.add(event);
    trim();
  }

  void trim() {
    final overflow = events.length - capacity;
    if (overflow <= 0) return;
    events.removeRange(0, overflow);
    dropped += overflow;
  }

  void clear() {
    events.clear();
    dropped = 0;
  }
}

final class _GInspectorActivityEvent {
  const _GInspectorActivityEvent({
    required this.sequence,
    required this.frame,
    required this.elapsed,
    required this.type,
    required this.data,
  });

  final int sequence;
  final int frame;
  final double elapsed;
  final String type;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => <String, Object?>{
    'sequence': sequence,
    'frame': frame,
    'elapsed': elapsed,
    'type': type,
    'data': data,
  };
}
