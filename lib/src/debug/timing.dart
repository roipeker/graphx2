part of 'package:graphx/src/graphx_impl.dart';

/// Monotonic clock shared by runtime diagnostics.
final Stopwatch _runtimeClock = Stopwatch()..start();

/// Milliseconds elapsed since GraphX initialized.
int getTimer() => _runtimeClock.elapsedMilliseconds;

/// Microseconds elapsed since GraphX initialized.
int getTimerMicros() => _runtimeClock.elapsedMicroseconds;

/// Monotonic elapsed runtime.
Duration get runtimeElapsed => _runtimeClock.elapsed;

/// Lightweight manually controlled timer.
final class GTimer {
  GTimer() : _startedAt = getTimerMicros();

  factory GTimer.start() => GTimer();

  int _startedAt;
  int _elapsedMicroseconds = 0;
  bool _running = true;

  bool get isRunning => _running;

  int get elapsedMicroseconds {
    return _running ? getTimerMicros() - _startedAt : _elapsedMicroseconds;
  }

  double get elapsedMilliseconds => elapsedMicroseconds / 1000.0;

  Duration get elapsed => Duration(microseconds: elapsedMicroseconds);

  void restart() {
    _startedAt = getTimerMicros();
    _elapsedMicroseconds = 0;
    _running = true;
  }

  int stop() {
    if (_running) {
      _elapsedMicroseconds = getTimerMicros() - _startedAt;
      _running = false;
    }
    return _elapsedMicroseconds;
  }

  @override
  String toString() => _formatDuration(elapsedMicroseconds);
}

String _formatDuration(int microseconds) {
  if (microseconds < 1000) return '$microseconds µs';
  final ms = microseconds / 1000.0;
  if (ms < 10.0) return '${ms.toStringAsFixed(3)} ms';
  if (ms < 100.0) return '${ms.toStringAsFixed(2)} ms';
  if (ms < 1000.0) return '${ms.toStringAsFixed(1)} ms';
  return '${(ms / 1000.0).toStringAsFixed(2)} s';
}
