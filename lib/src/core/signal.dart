// Copyright (c) 2026 GraphX by roipeker.

/// GraphX2 Signal
///
/// Lightweight synchronous event primitive used throughout GraphX2.
///
/// Design goals:
///
/// • Zero allocations during dispatch.
/// • Safe listener mutation while emitting.
/// • O(1) exact subscription cancellation.
/// • Typed payloads.
/// • Flutter-independent.
/// • Small memory footprint.
/// • Predictable behavior over maximum microbenchmark speed.
///
/// Ported from the mini_engine / sketchx Signal baseline (benchmarked on
/// macOS, iOS, Android, Chrome). Prefer correctness and predictable mutation
/// over chasing small microbenchmark deltas.
///
/// Please benchmark any modification before changing:
///
/// • listener storage
/// • dispatch loop
/// • compaction policy
/// • cancellation semantics
/// • mutation guarantees
///
/// See `benchmark/signal/signal_bench.dart`.
part of 'package:graphx/src/graphx_impl.dart';

typedef GSignalCallback<T> = void Function(T value);
typedef GSignalCallback0 = void Function();

/// Minimal common disposal contract for GraphX2 utilities.
///
/// Nodes, components, signals, and subscriptions share this so owners can
/// tear down listenables during a single cleanup phase.
// abstract interface class IDisposable {
//   void dispose();
// }

/// Handle for one exact signal registration.
///
/// Cancellation is idempotent and O(1).
abstract class GSignalSubscription implements _GDisposable {
  bool get isActive;

  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  void cancel();

  @override
  void dispose() {
    _disposed = true;
    cancel();
  }
}

/// Synchronous typed event signal.
///
/// ## Guarantees
///
/// - Listener storage is allocated lazily.
/// - [emit] allocates nothing.
/// - Listeners execute in registration order.
/// - Exact subscription cancellation is O(1).
/// - Callback/key removal is O(n).
/// - Removing a listener during dispatch takes effect immediately.
/// - Adding a listener during dispatch defers it from that dispatch.
/// - A nested emit creates its own dispatch boundary.
/// - Once-listeners are cancelled before invocation.
/// - Listener exceptions propagate, while internal state remains valid.
/// - Duplicate callbacks and duplicate keys are allowed.
/// - Optional [onListenerCountChanged] runs after every count mutation
///   (including once-listener auto-cancel during [emit]).
final class GSignal<T> implements _GDisposable {
  GSignal({this.onListenerCountChanged});

  /// Invoked after [listenerCount] changes. Used by demand-gated systems
  /// such as pointer input.
  final void Function(int listenerCount)? onListenerCountChanged;

  List<_SignalEntry<T>?>? _entries;

  int _listenerCount = 0;
  int _dispatchDepth = 0;
  bool _disposed = false;

  bool get hasListeners => _listenerCount != 0;

  int get listenerCount => _listenerCount;

  @override
  bool get isDisposed => _disposed;

  @override
  String toString() => 'Signal<$T>(listeners: $_listenerCount${_disposed ? ', disposed' : ''})';

  GSignalSubscription add(GSignalCallback<T> callback, {Object? key}) {
    return _add(callback, once: false, key: key);
  }

  GSignalSubscription addOnce(GSignalCallback<T> callback, {Object? key}) {
    return once(callback, key: key);
  }

  GSignalSubscription once(GSignalCallback<T> callback, {Object? key}) {
    return _add(callback, once: true, key: key);
  }

  _SignalEntry<T> _add(
    GSignalCallback<T> callback, {
    required bool once,
    required Object? key,
  }) {
    if (_disposed) {
      throw StateError('Cannot add a listener to a disposed Signal<$T>.');
    }

    final entries = _entries ??= <_SignalEntry<T>?>[];

    final _SignalEntry<T> entry;

    if (key == null) {
      entry = _SignalEntry<T>(
        owner: this,
        callback: callback,
        index: entries.length,
        once: once,
      );
    } else {
      entry = _KeyedSignalEntry<T>(
        owner: this,
        callback: callback,
        index: entries.length,
        once: once,
        key: key,
      );
    }

    entries.add(entry);
    _listenerCount++;
    _notifyListenerCountChanged();

    return entry;
  }

  /// Emits [value] synchronously to all active listeners.
  void emit(T value) {
    if (_disposed || _listenerCount == 0) {
      return;
    }

    final entries = _entries!;

    // Listeners added after this point do not belong to this dispatch.
    final dispatchLength = entries.length;

    _dispatchDepth++;

    try {
      for (var i = 0; i < dispatchLength; i++) {
        final entry = entries[i];
        if (entry == null) continue;

        final callback = entry._callback;
        if (callback == null) continue;

        // Cancel before invocation. A nested emit must not invoke the same
        // once-listener again.
        if (entry._once) {
          _cancel(entry);
        }

        callback(value);
      }
    } finally {
      _dispatchDepth--;

      if (_dispatchDepth == 0) {
        _compactIfNeeded();
      }
    }
  }

  bool remove(GSignalCallback<T> callback) {
    final entries = _entries;
    if (entries == null) return false;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      // Deliberately use function equality rather than identical().
      if (entry != null && entry._callback == callback) {
        _cancel(entry);
        return true;
      }
    }

    return false;
  }

  int removeKey(Object key) {
    final entries = _entries;
    if (entries == null) return 0;

    var removed = 0;

    // Bulk removal is implemented directly rather than calling _cancel().
    // _cancel() may compact storage, which would invalidate indexes while
    // this loop is running.
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry == null || !entry._matchesKey(key)) {
        continue;
      }

      entries[i] = null;
      entry._deactivate();

      _listenerCount--;
      removed++;
    }

    if (removed != 0) {
      _notifyListenerCountChanged();
      if (_dispatchDepth == 0) {
        _compactIfNeeded();
      }
    }

    return removed;
  }

  bool contains(GSignalCallback<T> callback) {
    final entries = _entries;
    if (entries == null) return false;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry != null && entry._callback == callback) {
        return true;
      }
    }

    return false;
  }

  bool containsKey(Object key) {
    final entries = _entries;
    if (entries == null) return false;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry != null && entry._matchesKey(key)) {
        return true;
      }
    }

    return false;
  }

  /// Removes all listeners.
  ///
  /// If called during [emit], listeners that have not executed yet are
  /// skipped immediately.
  void removeAll() {
    final entries = _entries;

    if (entries == null || _listenerCount == 0) {
      return;
    }

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry == null) continue;

      entries[i] = null;
      entry._deactivate();
    }

    _listenerCount = 0;
    _notifyListenerCountChanged();

    if (_dispatchDepth == 0) {
      entries.clear();
    }
  }

  /// Permanent signal teardown.
  ///
  /// Existing subscriptions become inactive. New registrations throw.
  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    removeAll();

    if (_dispatchDepth == 0) {
      _entries = null;
    }
  }

  void _cancel(_SignalEntry<T> entry) {
    if (!identical(entry._owner, this)) {
      return;
    }

    final entries = _entries;
    if (entries == null) return;

    final index = entry._index;

    if (index < 0 || index >= entries.length || !identical(entries[index], entry)) {
      return;
    }

    entries[index] = null;
    entry._deactivate();
    _listenerCount--;
    _notifyListenerCountChanged();

    if (_dispatchDepth == 0) {
      _compactIfNeeded();
    }
  }

  void _notifyListenerCountChanged() {
    onListenerCountChanged?.call(_listenerCount);
  }

  // Delayed compaction.
  //
  // Immediate compaction is measurably slower under subscription churn.
  // Dead slots are tolerated until a threshold is reached.
  //
  // See benchmark/signal/signal_bench.dart.
  void _compactIfNeeded() {
    final entries = _entries;
    if (entries == null) return;
    if (_listenerCount == 0) {
      entries.clear();
      if (_disposed) _entries = null;
      return;
    }

    final deadCount = entries.length - _listenerCount;

    // Avoid an O(n) compaction after every cancellation.
    // Small lists tolerate a few dead slots. Larger lists compact once half
    // or more of the allocated slots are dead.
    if (deadCount < 8 || deadCount * 2 < entries.length) return;

    var writeIndex = 0;

    for (var readIndex = 0; readIndex < entries.length; readIndex++) {
      final entry = entries[readIndex];
      if (entry == null) continue;
      if (writeIndex != readIndex) {
        entries[writeIndex] = entry;
      }
      entry._index = writeIndex;
      writeIndex++;
    }
    entries.length = writeIndex;
  }
}

base class _SignalEntry<T> extends GSignalSubscription {
  _SignalEntry({
    required GSignal<T> this._owner,
    required GSignalCallback<T> this._callback,
    required this._index,
    required this._once,
  });

  GSignal<T>? _owner;
  GSignalCallback<T>? _callback;

  int _index;
  final bool _once;

  @override
  bool get isActive => _owner != null;

  @override
  void cancel() {
    _owner?._cancel(this);
  }

  bool _matchesKey(Object key) => false;

  void _deactivate() {
    _owner = null;
    _callback = null;
    _index = -1;
  }
}

final class _KeyedSignalEntry<T> extends _SignalEntry<T> {
  _KeyedSignalEntry({
    required super.owner,
    required super.callback,
    required super.index,
    required super.once,
    required Object this._key,
  });

  Object? _key;

  @override
  bool _matchesKey(Object key) {
    return identical(_key, key);
  }

  @override
  void _deactivate() {
    _key = null;
    super._deactivate();
  }
}

/// Specialized zero-argument signal.
///
/// This avoids dummy values, `void` payloads, dynamic invocation, and wrapper
/// closures.
final class GSignal0 implements _GDisposable {
  GSignal0({this.onListenerCountChanged});

  /// Invoked after [listenerCount] changes.
  final void Function(int listenerCount)? onListenerCountChanged;

  List<_SignalEntry0?>? _entries;

  int _listenerCount = 0;
  int _dispatchDepth = 0;
  bool _disposed = false;

  bool get hasListeners => _listenerCount != 0;

  int get listenerCount => _listenerCount;

  @override
  bool get isDisposed => _disposed;

  @override
  String toString() => 'Signal0(listeners: $_listenerCount${_disposed ? ', disposed' : ''})';

  GSignalSubscription add(GSignalCallback0 callback, {Object? key}) {
    return _add(callback, once: false, key: key);
  }

  GSignalSubscription addOnce(GSignalCallback0 callback, {Object? key}) {
    return once(callback, key: key);
  }

  GSignalSubscription once(GSignalCallback0 callback, {Object? key}) {
    return _add(callback, once: true, key: key);
  }

  _SignalEntry0 _add(
    GSignalCallback0 callback, {
    required bool once,
    required Object? key,
  }) {
    if (_disposed) {
      throw StateError('Cannot add a listener to a disposed Signal0.');
    }

    final entries = _entries ??= <_SignalEntry0?>[];

    final _SignalEntry0 entry;

    if (key == null) {
      entry = _SignalEntry0(
        owner: this,
        callback: callback,
        index: entries.length,
        once: once,
      );
    } else {
      entry = _KeyedSignalEntry0(
        owner: this,
        callback: callback,
        index: entries.length,
        once: once,
        key: key,
      );
    }

    entries.add(entry);
    _listenerCount++;
    _notifyListenerCountChanged();

    return entry;
  }

  void emit() {
    if (_disposed || _listenerCount == 0) {
      return;
    }

    final entries = _entries!;
    final dispatchLength = entries.length;

    _dispatchDepth++;

    try {
      for (var i = 0; i < dispatchLength; i++) {
        final entry = entries[i];
        if (entry == null) continue;

        final callback = entry._callback;
        if (callback == null) continue;

        if (entry._once) {
          _cancel(entry);
        }

        callback();
      }
    } finally {
      _dispatchDepth--;

      if (_dispatchDepth == 0) {
        _compactIfNeeded();
      }
    }
  }

  bool remove(GSignalCallback0 callback) {
    final entries = _entries;
    if (entries == null) return false;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry != null && entry._callback == callback) {
        _cancel(entry);
        return true;
      }
    }

    return false;
  }

  int removeKey(Object key) {
    final entries = _entries;
    if (entries == null) return 0;

    var removed = 0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry == null || !entry._matchesKey(key)) {
        continue;
      }

      entries[i] = null;
      entry._deactivate();

      _listenerCount--;
      removed++;
    }

    if (removed != 0) {
      _notifyListenerCountChanged();
      if (_dispatchDepth == 0) {
        _compactIfNeeded();
      }
    }

    return removed;
  }

  bool contains(GSignalCallback0 callback) {
    final entries = _entries;
    if (entries == null) return false;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry != null && entry._callback == callback) {
        return true;
      }
    }

    return false;
  }

  bool containsKey(Object key) {
    final entries = _entries;
    if (entries == null) return false;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry != null && entry._matchesKey(key)) {
        return true;
      }
    }

    return false;
  }

  void removeAll() {
    final entries = _entries;

    if (entries == null || _listenerCount == 0) {
      return;
    }

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry == null) continue;
      entries[i] = null;
      entry._deactivate();
    }

    _listenerCount = 0;
    _notifyListenerCountChanged();

    if (_dispatchDepth == 0) {
      entries.clear();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    removeAll();

    if (_dispatchDepth == 0) {
      _entries = null;
    }
  }

  void _cancel(_SignalEntry0 entry) {
    if (!identical(entry._owner, this)) {
      return;
    }

    final entries = _entries;
    if (entries == null) return;

    final index = entry._index;

    if (index < 0 || index >= entries.length || !identical(entries[index], entry)) {
      return;
    }

    entries[index] = null;
    entry._deactivate();
    _listenerCount--;
    _notifyListenerCountChanged();

    if (_dispatchDepth == 0) {
      _compactIfNeeded();
    }
  }

  void _notifyListenerCountChanged() {
    onListenerCountChanged?.call(_listenerCount);
  }

  void _compactIfNeeded() {
    final entries = _entries;
    if (entries == null) return;

    if (_listenerCount == 0) {
      entries.clear();

      if (_disposed) {
        _entries = null;
      }

      return;
    }

    final deadCount = entries.length - _listenerCount;

    if (deadCount < 8 || deadCount * 2 < entries.length) {
      return;
    }

    var writeIndex = 0;

    for (var readIndex = 0; readIndex < entries.length; readIndex++) {
      final entry = entries[readIndex];
      if (entry == null) continue;

      if (writeIndex != readIndex) {
        entries[writeIndex] = entry;
      }

      entry._index = writeIndex;
      writeIndex++;
    }

    entries.length = writeIndex;
  }
}

base class _SignalEntry0 extends GSignalSubscription {
  _SignalEntry0({
    required GSignal0 this._owner,
    required GSignalCallback0 this._callback,
    required this._index,
    required this._once,
  });

  GSignal0? _owner;
  GSignalCallback0? _callback;

  int _index;
  final bool _once;

  @override
  bool get isActive => _owner != null;

  @override
  void cancel() {
    _owner?._cancel(this);
  }

  bool _matchesKey(Object key) => false;

  void _deactivate() {
    _owner = null;
    _callback = null;
    _index = -1;
  }
}

final class _KeyedSignalEntry0 extends _SignalEntry0 {
  _KeyedSignalEntry0({
    required super.owner,
    required super.callback,
    required super.index,
    required super.once,
    required Object this._key,
  });

  Object? _key;

  @override
  bool _matchesKey(Object key) {
    return identical(_key, key);
  }

  @override
  void _deactivate() {
    _key = null;
    super._deactivate();
  }
}
