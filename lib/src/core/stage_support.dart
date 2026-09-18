part of 'package:graphx/graphx.dart';

mixin _GStageUpdate {
  final _updaters = <GStageUpdatable?>[];
  int _updaterCount = 0;
  int _updaterHoles = 0;
  bool _updating = false;

  void _addUpdater(GStageUpdatable obj) {
    if (obj._updateSlot >= 0) return;
    obj._updateSlot = _updaters.length;
    _updaters.add(obj);
    _updaterCount++;
    _ensureTick();
  }

  void _removeUpdater(GStageUpdatable obj) {
    final slot = obj._updateSlot;
    if (slot < 0) return;
    assert(
      slot < _updaters.length && identical(_updaters[slot], obj),
      'Updater slot registry is corrupted.',
    );
    if (slot >= _updaters.length || !identical(_updaters[slot], obj)) {
      obj._updateSlot = -1;
      return;
    }
    _updaters[slot] = null;
    obj._updateSlot = -1;
    _updaterCount--;
    _updaterHoles++;
    if (!_updating) _compactUpdatersIfNeeded();
  }

  void _compactUpdatersIfNeeded() {
    if (_updaterHoles == 0) return;
    final updaters = _updaters;
    if (_updaterCount == 0) {
      updaters.clear();
      _updaterHoles = 0;
      return;
    }
    if (_updaterHoles < 8 || _updaterHoles * 4 < updaters.length) return;
    var j = 0;
    for (var i = 0; i < updaters.length; ++i) {
      final obj = updaters[i];
      if (obj == null) continue;
      if (j != i) updaters[j] = obj;
      obj._updateSlot = j++;
    }
    updaters.length = j;
    _updaterHoles = 0;
  }

  void _runUpdaters(double delta) {
    final updaters = _updaters;
    final end = updaters.length;
    _updating = true;
    try {
      for (var i = 0; i < end; ++i) {
        final obj = updaters[i];
        if (obj != null && obj.updatesEnabled) obj.update(delta);
      }
    } finally {
      _updating = false;
      _compactUpdatersIfNeeded();
    }
  }

  void _ensureTick();
}

mixin _GStageStats {
  GStats? _stats;

  /// Lazy diagnostics facade. Detailed instrumentation is disabled by default.
  GStats get stats => _stats ??= GStats._(this as GStage);

  GStats? get _activeStats {
    final stats = _stats;
    return stats != null && stats.enabled ? stats : null;
  }
}

final class GStageSignals implements Disposable {
  GStageSignals._({required this.updateListenersChanged});

  final Function(int) updateListenersChanged;

  bool _disposed = false;
  GSignal0? _reassemble;
  GSignal0? _dispose;
  GSignal<GSize>? _resize;
  GSignal<double>? _update;
  GSignal<double>? _postUpdate;
  GSignal<double>? _lateUpdate;
  GSignal<GEnvironmentChange>? _environment;
  GSignal<GFlutterSync>? _flutterSync;
  GSignal<BuildContext>? _flutterDependencies;

  GSignal<GEnvironmentChange> get onEnvironment =>
      (_environment ??= GSignal<GEnvironmentChange>());

  GSignal<GFlutterSync> get onFlutterSync =>
      (_flutterSync ??= GSignal<GFlutterSync>());

  GSignal<BuildContext> get onFlutterDependencies =>
      (_flutterDependencies ??= GSignal<BuildContext>());

  GSignal0 get onReassemble => (_reassemble ??= GSignal0());

  GSignal0 get onDispose => (_dispose ??= GSignal0());

  GSignal<GSize> get onResize => (_resize ??= GSignal<GSize>());

  /// Primary Stage update phase, after node updaters.
  GSignal<double> get onUpdate => (_update ??= GSignal<double>(
    onListenerCountChanged: updateListenersChanged,
  ));

  /// Runs after [onUpdate] and before [onLateUpdate].
  GSignal<double> get onPostUpdate => (_postUpdate ??= GSignal<double>(
    onListenerCountChanged: updateListenersChanged,
  ));

  /// Final Stage update phase before input frame teardown.
  GSignal<double> get onLateUpdate => (_lateUpdate ??= GSignal<double>(
    onListenerCountChanged: updateListenersChanged,
  ));

  bool get _hasUpdateListeners =>
      (_update?.hasListeners ?? false) ||
      (_postUpdate?.hasListeners ?? false) ||
      (_lateUpdate?.hasListeners ?? false);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dispose?.emit();

    _update?.dispose();
    _postUpdate?.dispose();
    _lateUpdate?.dispose();
    _reassemble?.dispose();
    _dispose?.dispose();
    _resize?.dispose();
    _environment?.dispose();
    _flutterSync?.dispose();
    _flutterDependencies?.dispose();
  }

  @override
  bool get isDisposed => _disposed;
}
