// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

/// Scene node that plays and renders a [GTextureSequence].
final class GAnimatedImage extends GNode {
  GAnimatedImage([GTextureSequence? sequence]) {
    setPaintSelf(true);
    this.sequence = sequence;
  }

  final _GImageRenderState _render = _GImageRenderState();
  GTextureSequence? _sequence;

  GTextureSequence? get sequence => _sequence;
  set sequence(GTextureSequence? value) {
    if (identical(_sequence, value)) return;
    _validateSequence(value);

    final oldWidth = _render.width;
    final oldHeight = _render.height;
    _sequence = value;
    _frame = 0;
    _frameElapsed = 0.0;
    _render.texture = value?.firstTexture;

    if (oldWidth != _render.width || oldHeight != _render.height) {
      invalidateBounds();
    }
    _syncPlaybackRegistration();
    invalidatePaint();
  }

  double get width => _render.width;
  double get height => _render.height;

  bool _playing = false;
  bool get playing => _playing;

  bool loop = true;

  double _playbackRate = 1.0;
  double get playbackRate => _playbackRate;
  set playbackRate(double value) {
    if (!value.isFinite || value < 0.0) {
      throw ArgumentError.value(
        value,
        'playbackRate',
        'Must be finite and >= 0.',
      );
    }
    if (_playbackRate == value) return;
    _playbackRate = value;
    _syncPlaybackRegistration();
  }

  int _frame = 0;

  int get frame => _frame;
  set frame(int value) => gotoFrame(value);

  int get currentFrame => _frame;

  double _frameElapsed = 0.0;

  GTexture? get currentTexture => _render.texture;

  GSignal<int>? _onFrame;
  GSignal0? _onLoop;
  GSignal0? _onComplete;

  GSignalView<int> get onFrame => (_onFrame ??= GSignal<int>()).view;
  GSignalView0 get onLoop => (_onLoop ??= GSignal0()).view;
  GSignalView0 get onComplete => (_onComplete ??= GSignal0()).view;

  ui.FilterQuality get filterQuality => _render.filterQuality;
  set filterQuality(ui.FilterQuality value) {
    if (_render.filterQuality == value) return;
    _render.filterQuality = value;
    invalidatePaint();
  }

  void play() {
    if (_playing) return;
    _playing = true;
    _syncPlaybackRegistration();
  }

  void stop() {
    if (!_playing) return;
    _playing = false;
    _syncPlaybackRegistration();
  }

  void gotoFrame(int frame) => _setFrame(frame, emit: true);

  void gotoAndStop(int frame) {
    _setFrame(frame, emit: true);
    stop();
  }

  void gotoAndPlay(int frame) {
    _setFrame(frame, emit: true);
    play();
  }

  void _setFrame(int value, {required bool emit}) {
    final sequence = _sequence;
    if (sequence == null) {
      if (value != 0) throw StateError('No texture sequence assigned.');
      _frame = 0;
      _frameElapsed = 0.0;
      return;
    }
    if (value < 0 || value >= sequence.frameCount) {
      throw RangeError.range(value, 0, sequence.frameCount - 1, 'frame');
    }

    final changed = _frame != value;
    _frameElapsed = 0.0;
    if (!changed) return;

    _applyFrame(sequence, value);
    if (emit) _onFrame?.emit(_frame);
    invalidatePaint();
  }

  void _applyFrame(GTextureSequence sequence, int value) {
    final oldWidth = _render.width;
    final oldHeight = _render.height;
    _frame = value;
    _render.texture = sequence.frames[value].texture;
    if (oldWidth != _render.width || oldHeight != _render.height) {
      invalidateBounds();
    }
  }

  bool get _canAnimate {
    final sequence = _sequence;
    return _playing &&
        _playbackRate > 0.0 &&
        sequence != null &&
        !sequence.isDisposed &&
        sequence.frameCount > 1 &&
        sequence.duration > Duration.zero;
  }

  void _syncPlaybackRegistration() {
    updatesEnabled = _canAnimate;
  }

  @override
  void update(double delta) {
    final sequence = _sequence;
    if (sequence == null || !_canAnimate) return;

    var remaining = delta * _playbackRate;
    if (remaining <= 0.0) return;

    var changed = false;
    while (remaining > 0.0 && _playing) {
      final micros = sequence.frames[_frame].duration.inMicroseconds;
      final duration = micros / Duration.microsecondsPerSecond;

      if (duration <= 0.0) {
        changed |= _advanceFrame(sequence);
        continue;
      }

      final left = duration - _frameElapsed;
      if (remaining < left) {
        _frameElapsed += remaining;
        break;
      }

      remaining -= left;
      _frameElapsed = 0.0;
      changed |= _advanceFrame(sequence);
    }

    if (changed && isAttached) stage.requestPaint();
  }

  bool _advanceFrame(GTextureSequence sequence) {
    final next = _frame + 1;
    if (next < sequence.frameCount) {
      _applyFrame(sequence, next);
      _onFrame?.emit(_frame);
      return true;
    }

    if (loop) {
      _applyFrame(sequence, 0);
      _onLoop?.emit();
      _onFrame?.emit(_frame);
      return true;
    }

    _playing = false;
    _syncPlaybackRegistration();
    _onComplete?.emit();
    return false;
  }

  @override
  void computeSelfBounds(GBounds out) {
    if (_render.texture == null) {
      out.setEmpty();
      return;
    }
    out.setXYWH(0.0, 0.0, _render.width, _render.height);
  }

  @override
  void paintSelf(GRenderContext context) {
    final sequence = _sequence;
    if (sequence?.isDisposed ?? false) {
      assert(
        false,
        'A GTextureSequence referenced by a live image was disposed.',
      );
      return;
    }
    _render.paint(context);
  }

  static void _validateSequence(GTextureSequence? sequence) {
    if (sequence == null) return;
    if (sequence.isDisposed) {
      throw StateError('Cannot assign a disposed GTextureSequence.');
    }
    for (var i = 0; i < sequence.frames.length; ++i) {
      if (sequence.frames[i].texture.isDisposed) {
        throw StateError('Cannot assign a sequence with disposed textures.');
      }
    }
  }

  @override
  void dispose() {
    _onFrame?.dispose();
    _onLoop?.dispose();
    _onComplete?.dispose();
    super.dispose();
  }
}
