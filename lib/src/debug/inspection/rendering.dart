// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

final _GInspectorRenderingRuntime _gInspectorRenderingRuntime = _GInspectorRenderingRuntime();

/// On-demand rendering explanations and opt-in live activity for DevTools.
///
/// Retained render-path facts are always derived from authoritative node state.
/// Detailed frame counters are never enabled merely by inspecting a Stage;
/// DevTools must explicitly request instrumentation and tracks whether it owns
/// that enablement so application-owned diagnostics are not disabled by tooling.
final class _GInspectorRenderingRuntime {
  static const _prefix = 'ext.graphx.inspector';

  final Expando<bool> _ownsStats = Expando<bool>(
    'graphx.inspector.renderStats',
  );
  bool _registered = false;

  void ensureRegistered() {
    assert(!kReleaseMode);
    if (_registered) return;
    _registered = true;
    developer.registerExtension('$_prefix.getRenderOverview', _handleOverview);
    developer.registerExtension('$_prefix.explainRender', _handleExplain);
    developer.registerExtension(
      '$_prefix.setRenderInstrumentation',
      _handleSetInstrumentation,
    );
  }

  Future<developer.ServiceExtensionResponse> _handleOverview(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _gInspectorRuntime._requireStage(parameters['stageId']);
      return _gInspectorRuntime._result(<String, Object?>{
        'rendering': _overview(stage),
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleExplain(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final node = _gInspectorRuntime._requireNode(parameters['nodeId']);
      return _gInspectorRuntime._result(<String, Object?>{
        'rendering': _explain(node),
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _handleSetInstrumentation(
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
      final current = stage._stats;
      if (enabled) {
        if (current == null || !current.enabled) {
          stage.stats.enabled = true;
          _ownsStats[stage] = true;
        }
      } else if (_ownsStats[stage] == true) {
        stage._stats?.enabled = false;
        _ownsStats[stage] = false;
      }
      return _gInspectorRuntime._result(<String, Object?>{
        'rendering': _overview(stage),
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Map<String, Object?> _overview(GStage stage) {
    final stats = stage._stats;
    final enabled = stats?.enabled ?? false;
    return <String, Object?>{
      'stageId': _gInspectorRuntime._idForStage(stage),
      'nodeCount': stage._nodeCount,
      'rasterCaches': stage._rasterCacheCount,
      'rasterCacheBytes': stage._rasterCacheBytes,
      'instrumentation': <String, Object?>{
        'allocated': stats != null,
        'enabled': enabled,
        'ownedByDevTools': _ownsStats[stage] == true,
      },
      if (enabled)
        'activity': <String, Object?>{
          'fps': stats!.frame.fps,
          'frameMilliseconds': stats.frame.frameMilliseconds,
          'lastFrameMilliseconds': stats.frame.lastFrameMilliseconds,
          'maxFrameMilliseconds': stats.frame.maxFrameMilliseconds,
          'paint': _timer(stats.render.paint),
          'nodesVisited': stats.render.nodesVisited.value,
          'nodesPainted': stats.render.nodesPainted.value,
          'transformsApplied': stats.render.transformsApplied.value,
          'canvasSaves': stats.render.canvasSaves.value,
          'saveLayers': stats.render.saveLayers.value,
          'clipsApplied': stats.render.clipsApplied.value,
          'masksApplied': stats.render.masksApplied.value,
          'cullChecks': stats.render.cullChecks.value,
          'culledChildren': stats.render.culledChildren.value,
          'cacheRasterize': _timer(stats.cache.rasterize),
        },
    };
  }

  Map<String, Object?> _timer(GStatsTimerMetric metric) => <String, Object?>{
    'count': metric.count,
    'lastMicroseconds': metric.lastMicroseconds,
    'averageMicroseconds': metric.averageMicroseconds,
    'maxMicroseconds': metric.maxMicroseconds,
  };

  Map<String, Object?> _explain(GNode node) {
    var effectiveAlpha = 1.0;
    var inheritedColorTransform = false;
    for (GNode? current = node; current != null; current = current._parent) {
      effectiveAlpha *= current._alpha;
      inheritedColorTransform =
          inheritedColorTransform || current._composite?.colorTransform != null;
    }

    final composite = node._composite;
    final filters = composite?.filters;
    final cache = node._cache;
    final cacheReady =
        cache != null &&
        cache.enabled &&
        cache.isReady &&
        cache._texture != null &&
        !cache._texture!.isDisposed &&
        cache._bounds != null;
    final requiresLayer = composite?.requiresLayer ?? false;
    final reasons = <Object>[];
    final notes = <String>[];

    if (cacheReady) {
      reasons.add(
        _reason(
          'cache.ready',
          'A ready retained raster can replace the live subtree in a full render pass.',
        ),
      );
    } else {
      if (composite?.mode == GCompositeMode.layer) {
        reasons.add(
          _reason(
            'composite.forced-layer',
            'Composite mode explicitly requests subtree isolation.',
          ),
        );
      }
      if (composite?.mask != null) {
        reasons.add(
          _reason(
            'composite.mask',
            'The alpha mask requires target isolation and an additional mask layer.',
          ),
        );
      }
      if (composite != null && composite.blendMode != ui.BlendMode.srcOver) {
        reasons.add(
          _reason(
            'composite.blend',
            'The ${composite.blendMode.name} node blend currently isolates the subtree.',
          ),
        );
      }
      if (filters != null) {
        reasons.add(
          _reason(
            composite!.hasBranchingFilter ? 'filter.branching' : 'filter.linear-chain',
            composite.hasBranchingFilter
                ? 'Branching filters require isolated effect work and may replay an uncached prefix.'
                : 'The ordered filter chain requires subtree isolation and can use one native linear chain.',
          ),
        );
      }
    }

    if (composite?.clip != null) {
      notes.add(
        'Clip is applied directly with Canvas clipping; it does not require isolation by itself.',
      );
    }
    if (inheritedColorTransform) {
      notes.add(
        'Color transform is inherited render state and does not require compositor isolation by itself.',
      );
    }
    if (effectiveAlpha > 0.0 && effectiveAlpha < 1.0) {
      notes.add(
        'Opacity is normally distributed into direct paints; black-box renderables may use a bounded fallback layer.',
      );
    }
    if (cache != null && cache.enabled && !cacheReady) {
      notes.add(
        cache.isBuilding
            ? 'Raster cache is building, so the live subtree remains the current source.'
            : 'Raster cache is enabled but not ready for the current content/quality state.',
      );
    }

    final route = cacheReady
        ? 'retained-cache'
        : requiresLayer
        ? 'isolated-layer'
        : 'direct';

    return <String, Object?>{
      'node': _gInspectorRuntime._nodeSummary(node),
      'route': route,
      'effectiveAlpha': effectiveAlpha,
      'reasons': reasons,
      'notes': notes,
      'compositing': <String, Object?>{
        'mode': (composite?.mode ?? GCompositeMode.auto).name,
        'requiresLayer': requiresLayer,
        'directConflict': composite?.directConflict ?? false,
        'blendMode': (composite?.blendMode ?? ui.BlendMode.srcOver).name,
        'clip': composite?.clip?.runtimeType.toString(),
        'maskId': composite?.mask == null
            ? null
            : _gInspectorRuntime._idForObject(composite!.mask!),
        'maskMode': (composite?.maskMode ?? GMaskMode.alpha).name,
        'filterCount': filters?.length ?? 0,
        'filters': <String>[
          if (filters != null)
            for (final filter in filters) filter.runtimeType.toString(),
        ],
        'branchingFilters': composite?.hasBranchingFilter ?? false,
        'hasLocalColorTransform': composite?.colorTransform != null,
        'hasInheritedColorTransform': inheritedColorTransform,
      },
      'cache': <String, Object?>{
        'allocated': cache != null,
        'enabled': cache?.enabled ?? false,
        'ready': cacheReady,
        'dirty': cache?.isDirty ?? false,
        'building': cache?.isBuilding ?? false,
        'retainedBytes': cache?._retainedBytes ?? 0,
        'pixelWidth': cache?.pixelWidth ?? 0,
        'pixelHeight': cache?.pixelHeight ?? 0,
        'rasterScale': cache?.rasterScale ?? 0.0,
        'captures': cache?.captures ?? 0,
      },
    };
  }

  Map<String, Object?> _reason(String code, String message) => <String, Object?>{
    'code': code,
    'message': message,
  };
}
