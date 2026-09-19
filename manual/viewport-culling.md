# Viewport culling

Build a world ten screens wide.

Most of it is offscreen at any moment, but the retained nodes still exist because the camera may come back later.

The renderer does not always need to visit and paint all of them.

## `GViewportGroup` skips offscreen child subtrees

```dart
final world = root.addChild(GViewportGroup());
```

Children outside the active render viewport can be rejected during rendering.

That changes **painting only**.

Offscreen nodes remain:

```text
attached
updating (if they have updates)
available to input/hit testing
part of bounds/hierarchy
alive in memory
```

This is culling, not scene removal.

## Why not make every `GNode` do this?

Culling has a cost too: bounds must be inspected and compared against the viewport.

A tiny UI with twenty nodes may gain nothing from performing extra cull checks.

`GViewportGroup` opts a branch into that behavior when its scale makes the trade worthwhile.

That keeps ordinary `GNode` traversal simple.

## One giant group still has to check its direct children

Suppose the world has 10,000 direct children:

```text
world: GViewportGroup
├── tile 1
├── tile 2
├── tile 3
├── ...
└── tile 10000
```

GraphX can skip painting offscreen children, but it still needs to test those direct children to discover which ones are outside.

For very large worlds, spatial chunks are better.

## Cull whole chunks at once

```dart
final world = root.addChild(GViewportGroup());

final chunk = world.addChild(
  GViewportGroup(
    cullBounds: GRect(0, 0, 1024, 1024),
  ),
);
```

Put many nearby objects inside that chunk.

Now an ancestor viewport group can reject the complete chunk from one conservative rectangle before walking all of its descendants.

```text
world
├── chunk A (1024×1024)
│   ├── hundreds of objects
│   └── ...
├── chunk B
└── chunk C
```

That is the usual large-world idea: first reject large regions, then inspect objects only inside potentially visible regions.

## `cullBounds` must be conservative

If you provide it, the rectangle needs to contain **all pixels that descendants may render**, including effects such as shadows/glows.

Too large is safe but less efficient.

Too small can incorrectly reject visible content.

When `cullBounds` is absent, GraphX derives effect bounds as needed instead of trusting an incomplete hint.

## Camera/render views are respected

With explicit `GRenderView`s, culling uses the active view/Canvas clip transformed into the group's local space.

So the same large world can be culled correctly for a zoomed main camera and then rendered again for a minimap view.

The retained world does not have to move just to make culling understand the camera.

## Snapshots and raster caches ignore hosted viewport culling

This is subtle and important.

If you snapshot a large `GViewportGroup`, you usually expect the requested subtree/area—not “only whatever happened to be visible in the current window.”

Likewise, a raster cache must capture complete retained content rather than baking the current host viewport accident into the texture.

GraphX therefore bypasses viewport culling for those capture paths.

Culling is a hosted rendering optimization, not a mutation of canonical scene content.

## Filters on the group stay conservative

A filter applied to the `GViewportGroup` itself can make descendant pixels influence an area outside their raw bounds.

GraphX currently keeps that uncommon case conservative and avoids group culling where it cannot prove the effect influence safely.

Correct pixels beat an aggressive cull.

## Measure whether culling is paying off

Detailed stats expose:

```dart
stage.stats.render.cullChecks.value
stage.stats.render.culledChildren.value
```

That gives you evidence instead of assuming a culling hierarchy is helping.

At a camera zoom where almost everything becomes visible, you can even disable the specialization temporarily:

```dart
world.cullingEnabled = false;
```

A performance feature should earn its complexity from the scene you actually have.
