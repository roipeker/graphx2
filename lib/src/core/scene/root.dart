// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

class GRoot extends GNode {
  GRoot({super.name});

  GSignal<double> get onUpdate => stage.signals.onUpdate;

  GSignal<GSize> get onResize => stage.signals.onResize;

  GSignal<GEnvironmentChange> get onEnvironment => stage.signals.onEnvironment;

  GKeyboardManager get keyboard => stage.input.keyboard;

  /// Called after [attached] with the first usable viewport and whenever the
  /// stage viewport changes afterwards. The same values are available from
  /// [stage.width] and [stage.height].
  @protected
  void resize(double w, double h) {}

  /// Called when a consumed host environment property changes.
  @protected
  void environmentChanged(GEnvironmentChange change) {}

  @protected
  void reassemble() {}

  void _attachRoot() {
    final stage = _stage;
    if (stage == null) {
      throw StateError('Root must belong to a stage before attachment.');
    }
    if (!stage._rootAttached) {
      throw StateError('Stage must establish root attachment first.');
    }
    _dispatchAttachedSubtree();
  }

  @override
  void dispose() {
    if (isDisposed) return;
    final stage = _stage;
    if (stage != null && !stage.isDisposed) {
      throw StateError(
        'Cannot dispose an attached Stage root; dispose the Stage instead.',
      );
    }
    _detachFromStage();
    super.dispose();
    if (stage != null) _disposeStageFocus(stage);
  }
}
