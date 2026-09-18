part of 'package:graphx/src/graphx_impl.dart';

/// Container that skips direct child subtrees outside the current render viewport.
///
/// Culling affects rendering only. Offscreen descendants remain attached, keep
/// receiving updates, and participate in input exactly like descendants of a
/// normal [GNode]. Nest viewport groups to create cheap hierarchical scene
/// chunks.
///
/// [cullBounds] is an optional conservative extent in this group's local space.
/// It is primarily useful when this group is itself nested below another
/// [GViewportGroup]: an ancestor can reject the whole subtree from this one
/// rectangle without walking descendants to derive their effect bounds. Keep it
/// large enough to contain every rendered descendant, including child effects.
final class GViewportGroup extends GNode {
  GViewportGroup({this.cullBounds, super.name});

  /// Optional conservative local extent used as a fast culling hint.
  ///
  /// The rectangle is read directly during rendering. When mutating it while an
  /// otherwise idle scene is visible, request a repaint through the stage.
  final GRect? cullBounds;

  /// Enables viewport rejection for this group.
  ///
  /// Turning this off preserves normal child traversal and is useful when a
  /// camera zoom level makes nearly every child visible, or for diagnostics.
  /// It never changes update, lifecycle, input, or retained raster contents.
  bool get cullingEnabled => _cullingEnabled;
  set cullingEnabled(bool value) {
    if (_cullingEnabled == value) return;
    _cullingEnabled = value;
    // Cached/snapshot captures intentionally ignore viewport culling, so this
    // is only a hosted traversal change and must not invalidate retained pixels.
    _stage?.requestPaint();
  }

  bool _cullingEnabled = true;

  // Scratch belongs to the specialized container so ordinary GNode instances
  // pay no storage cost for viewport culling.
  final GRect _cullView = GRect();
  final GBounds _cullBoundsScratch = GBounds.empty();
  final GBounds _cullTransformedScratch = GBounds.empty();
  final GBounds _stageViewportScratch = GBounds.empty();
  final GBounds _localViewportScratch = GBounds.empty();
  final GMatrix2 _inverseWorldScratch = GMatrix2();
  final List<GBounds> _effectBoundsScratch = <GBounds>[];
}

extension _GViewportGroupRenderer on GCanvasRenderer {
  void _paintViewportGroupChildren(
    GViewportGroup group,
    GRenderContext context,
    double childParentAlpha,
    GRenderStats? stats,
  ) {
    final children = group._children;
    if (children == null) return;

    // Snapshots/raster-cache captures must contain the complete subtree rather
    // than whatever happens to be visible in the hosted Stage viewport.
    if (!group.cullingEnabled ||
        !_allowRasterCache ||
        _viewportGroupOwnFilter(group)) {
      _paintViewportChildrenUnculled(
        children,
        context,
        childParentAlpha,
        stats,
      );
      return;
    }

    final view = _viewportGroupLocalView(group, context);
    if (view == null) {
      _paintViewportChildrenUnculled(
        children,
        context,
        childParentAlpha,
        stats,
      );
      return;
    }

    final declared = group.cullBounds;
    if (declared != null) {
      stats?.cullChecks.increment();
      if (!declared.intersects(view)) {
        stats?.culledChildren.increment(children.length);
        return;
      }
    }

    for (var i = 0; i < children.length; ++i) {
      final child = children[i];
      // Preserve the renderer's normal visited/visibility accounting while
      // avoiding an effect-bounds query that can never help hidden children.
      if (!child.active || !child._visible) {
        _paintNode(child, context, childParentAlpha, stats);
        continue;
      }

      stats?.cullChecks.increment();
      if (!_viewportChildIntersects(group, child, view)) {
        stats?.culledChildren.increment();
        continue;
      }
      _paintNode(child, context, childParentAlpha, stats);
    }
  }

  void _paintViewportChildrenUnculled(
    List<GNode> children,
    GRenderContext context,
    double childParentAlpha,
    GRenderStats? stats,
  ) {
    for (var i = 0; i < children.length; ++i) {
      _paintNode(children[i], context, childParentAlpha, stats);
    }
  }

  /// Returns the active output clip conservatively expressed in this group's
  /// local coordinates. Explicit render views already put their camera matrix
  /// on Canvas, so Canvas can perform the inverse transform for culling without
  /// teaching node world transforms about cameras.
  GRect? _viewportGroupLocalView(GViewportGroup group, GRenderContext context) {
    if (context.renderView != null) {
      final clip = context.canvas.getLocalClipBounds();
      if (!clip.isFinite) return null;
      if (clip.isEmpty) {
        group._cullView.setEmpty();
      } else {
        group._cullView.set(clip.left, clip.top, clip.width, clip.height);
      }
      return group._cullView;
    }

    final stage = context.stage;
    final w = stage.width;
    final h = stage.height;
    if (!w.isFinite || !h.isFinite || w <= 0.0 || h <= 0.0) return null;

    group._ensureWorldTransform();
    if (!group._worldMatrix!.invertInto(group._inverseWorldScratch))
      return null;

    group._stageViewportScratch.setXYWH(0.0, 0.0, w, h);
    group._inverseWorldScratch.transformBoundsInto(
      group._stageViewportScratch,
      group._localViewportScratch,
    );
    group._localViewportScratch.writeRect(group._cullView);

    final clip = context.canvas.getLocalClipBounds();
    if (!clip.isFinite) return group._cullView;
    if (clip.isEmpty) {
      group._cullView.setEmpty();
      return group._cullView;
    }

    final view = group._cullView;
    final x1 = math.max(view.left, clip.left);
    final y1 = math.max(view.top, clip.top);
    final x2 = math.min(view.right, clip.right);
    final y2 = math.min(view.bottom, clip.bottom);
    if (x2 <= x1 || y2 <= y1) {
      view.setEmpty();
    } else {
      view.set(x1, y1, x2 - x1, y2 - y1);
    }
    return view;
  }

  bool _viewportChildIntersects(GViewportGroup group, GNode child, GRect view) {
    if (view.isEmpty) return false;

    final bounds = group._cullBoundsScratch;
    final declared = child is GViewportGroup ? child.cullBounds : null;
    if (declared != null) {
      bounds.setXYWH(declared.x, declared.y, declared.w, declared.h);
      final filters = child._composite?.filters;
      if (filters != null) {
        for (var i = 0; i < filters.length; ++i) {
          filters[i]._expandBounds(bounds);
        }
      }
    } else {
      _computeInspectionEffectBounds(
        child,
        bounds,
        group._effectBoundsScratch,
        0,
      );
    }

    if (bounds.isEmpty) return false;

    GBounds resolved = bounds;
    if (child.hasLocalTransform) {
      child.localMatrix.transformBoundsInto(
        bounds,
        group._cullTransformedScratch,
      );
      resolved = group._cullTransformedScratch;
    }

    return resolved.x1 < view.right &&
        resolved.x2 > view.left &&
        resolved.y1 < view.bottom &&
        resolved.y2 > view.top;
  }

  /// A filter on the group itself can make pixels outside the raw child extent
  /// contribute to the viewport. Keep that uncommon case conservative until a
  /// backend-independent inverse effect-influence contract exists.
  bool _viewportGroupOwnFilter(GViewportGroup group) {
    final filters = group._composite?.filters;
    return filters != null && filters.isNotEmpty;
  }
}
