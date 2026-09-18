part of 'package:graphx/graphx.dart';

enum GraphxReloadMode { retain, restart }

/// Defines how an input-enabled GraphxView participates in Flutter hit testing.
///
/// [opaque] claims the full GraphxView viewport.
/// [content] claims only positions that resolve to an interactive GraphX node.
enum GHitTestBehavior { opaque, content }

final class GraphxConfig {
  const GraphxConfig({
    this.reloadMode = GraphxReloadMode.retain,
    this.repaintBoundary = true,
    this.maxDelta = 1.0 / 15.0,
    this.pointer = true,
    this.hitTestBehavior = GHitTestBehavior.opaque,
    this.keyboard = false,
    this.autofocus = false,
  });

  // recommended for class based roots
  static const defaults = GraphxConfig();

  // recommended for callback scenes
  static const sceneDefaults = GraphxConfig(
    reloadMode: GraphxReloadMode.restart,
  );

  final GraphxReloadMode reloadMode;
  final bool repaintBoundary;
  final double maxDelta;

  final bool pointer;
  final GHitTestBehavior hitTestBehavior;
  final bool keyboard;

  // request Flutter focus when surface is attached.
  // should remain `false` for GraphxView usage in lists, forms, dialogs
  final bool autofocus;

  bool get inputEnabled => pointer || keyboard;

  GraphxConfig copyWith({
    GraphxReloadMode? reloadMode,
    bool? repaintBoundary,
    double? maxDelta,
    bool? pointer,
    GHitTestBehavior? hitTestBehavior,
    bool? keyboard,
    bool? autofocus,
  }) {
    return GraphxConfig(
      reloadMode: reloadMode ?? this.reloadMode,
      repaintBoundary: repaintBoundary ?? this.repaintBoundary,
      maxDelta: maxDelta ?? this.maxDelta,
      pointer: pointer ?? this.pointer,
      hitTestBehavior: hitTestBehavior ?? this.hitTestBehavior,
      keyboard: keyboard ?? this.keyboard,
      autofocus: autofocus ?? this.autofocus,
    );
  }
}
