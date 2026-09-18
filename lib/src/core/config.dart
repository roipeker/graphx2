// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

enum GraphXReloadMode { retain, restart }

/// Defines how an input-enabled GraphXView participates in Flutter hit testing.
///
/// [opaque] claims the full GraphXView viewport.
/// [content] claims only positions that resolve to an interactive GraphX node.
enum GHitTestBehavior { opaque, content }

final class GraphXConfig {
  const GraphXConfig({
    this.reloadMode = GraphXReloadMode.retain,
    this.repaintBoundary = true,
    this.maxDelta = 1.0 / 15.0,
    this.pointer = true,
    this.hitTestBehavior = GHitTestBehavior.opaque,
    this.keyboard = false,
    this.autofocus = false,
  });

  // recommended for class based roots
  static const defaults = GraphXConfig();

  // recommended for callback scenes
  static const sceneDefaults = GraphXConfig(
    reloadMode: GraphXReloadMode.restart,
  );

  final GraphXReloadMode reloadMode;
  final bool repaintBoundary;
  final double maxDelta;

  final bool pointer;
  final GHitTestBehavior hitTestBehavior;
  final bool keyboard;

  // request Flutter focus when surface is attached.
  // should remain `false` for GraphXView usage in lists, forms, dialogs
  final bool autofocus;

  bool get inputEnabled => pointer || keyboard;

  GraphXConfig copyWith({
    GraphXReloadMode? reloadMode,
    bool? repaintBoundary,
    double? maxDelta,
    bool? pointer,
    GHitTestBehavior? hitTestBehavior,
    bool? keyboard,
    bool? autofocus,
  }) {
    return GraphXConfig(
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
