part of 'package:graphx/src/graphx_impl.dart';

abstract interface class GStageHost {
  void scheduleTick();

  void schedulePaint();

  void updateCursor(GCursor cursor);
}

class GStage with _GStageUpdate, _GStageStats implements _GDisposable {
  GStage(
    this.root, {
    double maxDelta = 1 / 15.0,
    bool inputEnabled = true,
    GRuntime? runtime,
  }) : _maxDelta = _validateMaxDelta(maxDelta),
       _runtime = runtime ?? GRuntime(),
       _ownsRuntime = runtime == null {
    input = GInput._(this, enabled: inputEnabled);
  }

  final GRoot root;
  double _maxDelta;
  late final GInput input;

  GPointerManager get pointer => input.pointer;

  _GNodePointerRouter? _nodePointerRouter;

  _GNodePointerRouter _ensureNodePointerRouter() =>
      _nodePointerRouter ??= _GNodePointerRouter(this);

  double get maxDelta => _maxDelta;

  set maxDelta(double value) {
    _maxDelta = _validateMaxDelta(value);
  }

  static double _validateMaxDelta(double value) {
    if (!value.isFinite || value <= 0.0) {
      throw ArgumentError.value(value, 'maxDelta');
    }
    return value;
  }

  GRuntime _runtime;
  bool _ownsRuntime;

  GRuntime get runtime => _runtime;
  GAssets get assets => _runtime.assets;

  void _setRuntime(GRuntime? runtime) {
    if (runtime == null && _ownsRuntime) return;
    if (runtime != null && identical(runtime, _runtime)) return;

    final previous = _runtime;
    final owned = _ownsRuntime;
    _runtime = runtime ?? GRuntime();
    _ownsRuntime = runtime == null;

    if (owned) previous.dispose();
  }

  GStageHost? _host;
  bool _mounted = false;
  bool _rootAttached = false;
  bool _disposed = false;
  bool _ticking = false;

  bool _needsPaint = false;
  bool _updateRequested = false;
  bool _tickScheduled = false;
  bool _environmentBuildScheduled = false;
  bool _postRenderPaintScheduled = false;
  int _renderPassDepth = 0;

  Duration? _lastHostTimestamp;

  double delta = 0.0;
  double elapsed = 0.0;
  int frame = 0;
  int _nodeCount = 0;
  int _rasterCacheCount = 0;
  int _rasterCacheBytes = 0;

  double width = 0.0;
  double height = 0.0;
  double devicePixelRatio = 1.0;
  late final _viewportSize = GSize(width, height);

  BuildContext? _flutterContext;
  GEnvironment? _environment;

  GEnvironment get environment => _environment ??= GEnvironment._(this);

  GStageSignals? _signals;

  GStageSignals get signals => (_signals ??= GStageSignals._(
    updateListenersChanged: _updateListenersChanged,
  ));

  @override
  bool get isDisposed => _disposed;

  bool get isMounted => _mounted;

  bool get isHosted => _host != null;

  bool get needsPaint => _needsPaint;

  void _syncCursor() => _host?.updateCursor(pointer._effectiveCursor);

  void _updateListenersChanged(int count) {
    if (count > 0) {
      _ensureTick();
    }
  }

  /// Whether the Stage has a source that intentionally keeps ticking.
  /// One-shot input/requestUpdate work is not considered continuous.
  bool get hasContinuousUpdates =>
      _updaterCount > 0 || (_signals?._hasUpdateListeners ?? false);

  bool get wantsUpdate => _updateRequested || hasContinuousUpdates;

  /// Establishes permanent root ownership. Root lifecycle attachment is
  /// intentionally deferred until [setViewport] receives a usable size.
  void mount() {
    _checkAlive();
    if (_mounted) return;
    if (root.isDisposed) throw StateError('Cannot mount a disposed root.');
    root._checkStructureMutation();
    final owner = root._stage;
    if (owner != null && !identical(owner, this)) {
      throw StateError('Root is already attached to another stage');
    }

    root._attachToStage(this);
    _mounted = true;
    if (!kReleaseMode) {
      _gInspectorRuntime.registerStage(this);
      _gInspectorPickerRuntime.registerStage(this);
      _gInspectorActivityRuntime.registerStage(this);
      _gInspectorCaptureRuntime.registerStage(this);
    }
    requestPaint();
  }

  void attachHost(GStageHost host) {
    _checkAlive();
    if (!_mounted) {
      throw StateError('Mount the stage before attaching to a host.');
    }
    final current = _host;
    if (current != null && !identical(current, host)) {
      throw StateError('Stage already attached to another host');
    }
    if (identical(current, host)) return;
    _host = host;
    _tickScheduled = false;
    _lastHostTimestamp = null;

    host.updateCursor(pointer._effectiveCursor);

    if (_needsPaint) host.schedulePaint();
    if (wantsUpdate) _ensureTick();
  }

  void detachHost(GStageHost host) {
    if (!identical(_host, host)) return;
    _host = null;
    _tickScheduled = false;
    _lastHostTimestamp = null;
  }

  void setViewport(double w, double h, {double devicePixelRatio = 1.0}) {
    _checkAlive();
    if (width == w &&
        height == h &&
        this.devicePixelRatio == devicePixelRatio) {
      return;
    }
    _requireNotRendering('change the Stage viewport');

    _viewportSize.width = width = w;
    _viewportSize.height = height = h;
    this.devicePixelRatio = devicePixelRatio;

    final firstUsableViewport =
        !_rootAttached && w.isFinite && h.isFinite && w > 0.0 && h > 0.0;

    if (firstUsableViewport) {
      _rootAttached = true;
      root._attachRoot();
    }

    if (_rootAttached) root.resize(w, h);
    _signals?._resize?.emit(_viewportSize);

    if (firstUsableViewport && wantsUpdate) _ensureTick();
    requestPaint();
  }

  void _setFlutterContext(BuildContext context) {
    _flutterContext = context;
  }

  void _syncEnvironment(BuildContext context) {
    _flutterContext = context;
    final environment = _environment;
    if (environment == null) return;
    final changed = environment._sync(context);
    if (changed == 0 || !_rootAttached) return;

    final change = GEnvironmentChange._(changed);
    root.environmentChanged(change);
    _signals?._environment?.emit(change);
  }

  void _environmentRequirementsChanged() {
    final context = _flutterContext;
    final environment = _environment;
    if (context == null ||
        environment == null ||
        !environment._needsHostSync ||
        _environmentBuildScheduled) {
      return;
    }

    _environmentBuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _environmentBuildScheduled = false;
      if (_disposed ||
          !context.mounted ||
          !(_environment?._needsHostSync ?? false)) {
        return;
      }
      if (context case final Element element) element.markNeedsBuild();
    });
  }

  void _syncFlutter(
    BuildContext context,
    Object? value, {
    required bool dependenciesChanged,
  }) {
    _flutterContext = context;
    if (!_rootAttached) return;
    final signals = _signals;
    if (dependenciesChanged) {
      signals?._flutterDependencies?.emit(context);
    }
    final flutterSync = signals?._flutterSync;
    if (flutterSync != null && flutterSync.hasListeners) {
      flutterSync.emit(GFlutterSync<Object?>(context, value));
    }
  }

  void requestPaint() {
    _nodePointerRouter?._markSceneChanged();
    if (_disposed || _needsPaint) return;
    _needsPaint = true;
    if (_renderPassDepth == 0) _host?.schedulePaint();
  }

  void requestUpdate() {
    if (_disposed) return;
    _updateRequested = true;
    _ensureTick();
  }

  void handleFrame(Duration timestamp) {
    _checkAlive();
    _tickScheduled = false;
    final prev = _lastHostTimestamp;
    _lastHostTimestamp = timestamp;
    final rawDelta = prev == null
        ? 0.0
        : (timestamp - prev).inMicroseconds / Duration.microsecondsPerSecond;
    tick(rawDelta);
    if (!wantsUpdate) _lastHostTimestamp = null;
  }

  void tick(double rawDelta) {
    _checkAlive();
    if (!_mounted) throw StateError('Stage is not mounted');
    if (!_rootAttached) {
      throw StateError('Stage has no usable viewport.');
    }
    if (_ticking) throw StateError('Cannot tick a Stage recursively.');

    _ticking = true;
    try {
      final stats = _activeStats;
      stats?.frame.record(rawDelta);
      final dt = !rawDelta.isFinite || rawDelta <= 0.0
          ? 0.0
          : rawDelta.clamp(0.0, maxDelta);
      delta = dt;
      elapsed += dt;
      frame++;

      final startedAt = stats == null ? 0 : getTimerMicros();
      input._beginFrame();
      _updateRequested = false;
      try {
        _runUpdaters(delta);
        final signals = _signals;
        signals?._update?.emit(dt);
        signals?._postUpdate?.emit(dt);
        signals?._lateUpdate?.emit(dt);
      } finally {
        input._endFrame();
        stats?.frame.update.record(getTimerMicros() - startedAt);
      }

      if (wantsUpdate) _ensureTick();
    } finally {
      _ticking = false;
    }
  }

  void consumePaintRequest() {
    _needsPaint = false;
  }

  @override
  void dispose() {
    if (_disposed) return;
    if (_ticking) throw StateError('Cannot dispose the Stage during update.');
    _requireNotRendering('dispose the Stage');

    final rootOwner = root._stage;
    final disposeRoot = rootOwner == null || identical(rootOwner, this);
    if (!kReleaseMode) {
      _gInspectorActivityRuntime.unregisterStage(this);
      _gInspectorPickerRuntime.unregisterStage(this);
      _gInspectorRuntime.unregisterStage(this);
    }
    _disposed = true;
    _mounted = false;
    _host = null;
    _needsPaint = false;
    _updateRequested = false;
    _tickScheduled = false;
    _environmentBuildScheduled = false;
    _lastHostTimestamp = null;
    assert(_renderPassDepth == 0);
    _postRenderPaintScheduled = false;
    _nodePointerRouter?.dispose();
    _nodePointerRouter = null;
    input.dispose();
    if (disposeRoot) root.dispose();
    _rootAttached = false;
    _nodeCount = 0;
    _signals?.dispose();
    _environment = null;
    _flutterContext = null;
    if (_ownsRuntime) _runtime.dispose();
  }

  void _checkAlive() {
    if (_disposed) throw StateError('Stage is disposed.');
  }

  void _checkStructureMutation() {
    if (_renderPassDepth != 0) {
      throw StateError('Scene structure cannot be mutated during render.');
    }
  }

  void _requireNotRendering(String operation) {
    if (_renderPassDepth != 0) {
      throw StateError('Cannot $operation during render.');
    }
  }

  @override
  void _ensureTick() {
    final host = _host;
    if (!_mounted ||
        !_rootAttached ||
        host == null ||
        _tickScheduled ||
        !wantsUpdate ||
        _disposed) {
      return;
    }
    _tickScheduled = true;
    host.scheduleTick();
  }

  void reassemble() {
    _signals?._reassemble?.emit();
    root.reassemble();
  }

  void beginRenderPass() {
    _renderPassDepth++;
  }

  void endRenderPass() {
    assert(_renderPassDepth > 0);
    if (_renderPassDepth <= 0) return;
    _renderPassDepth--;
    final host = _host;
    if (_renderPassDepth != 0 ||
        !_needsPaint ||
        _disposed ||
        _postRenderPaintScheduled ||
        host == null) {
      return;
    }

    _postRenderPaintScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _postRenderPaintScheduled = false;
      if (_disposed || !_needsPaint || !identical(_host, host)) return;
      host.schedulePaint();
    });
  }
}
