# Performance

A fast scene is rarely the result of one secret optimization.

It is usually the result of doing less unnecessary work while keeping the simple path simple.

GraphX is designed around that idea, but scene structure still matters.

## Start with the cheapest representation that matches the problem

A transform is cheaper than rebuilding geometry just to move it.

```dart
node.x += 4;
```

is conceptually different from clearing/redrawing a complex path at a new coordinate every frame.

Likewise:

- hide a whole branch with `visible = false` when it should not render/interact;
- use `active = false` when the branch should stop participating more broadly;
- use `pointer.enabled = false` when visuals remain but pointer hit testing should skip the branch;
- use a clip when geometric clipping is enough instead of paying for a mask;
- let `GCompositeMode.auto` stay direct unless visual semantics require isolation.

The earlier chapters were quietly performance chapters too because they explained which work each abstraction asks the engine to do.

## Scene hierarchy can remove work in large chunks

A good retained hierarchy lets GraphX make coarse decisions.

If an entire hidden branch contains 5,000 descendants, GraphX can reject the branch at the parent instead of visiting 5,000 unrelated nodes and discovering individually that nothing should paint.

The same idea appears in render masks, pointer-interest tracking, semantics, and focus: optional systems stay demand-driven so large decorative scenes do not automatically pay interactive/control costs.

## `saveLayer()` is a visual feature with a cost

Masks, filters, non-default node blending, and explicit `GCompositeMode.layer` need isolated pixel composition.

That is not “bad.” It is how those effects work.

But if a scene suddenly gains hundreds of isolated layers, diagnostics can show it:

```dart
stage.stats.render.saveLayers.value
```

Then you can decide whether every layer is actually buying a visible result.

## Cache expensive stable pixels

Raster caching can be excellent when:

```text
subtree pixels: complicated + mostly stable
whole object transform: moving
```

and poor when:

```text
subtree pixels: changing every frame
cache: rebuilt every frame
```

Caching trades CPU/render work for retained texture memory. Measure both sides.

## Image decode size is part of rendering performance

Loading a 6000 px photo and drawing it at 120 px still paid for a huge decoded image.

When the real requirement is a thumbnail:

```dart
await stage.assets.texture(
  'images/photo.jpg',
  targetWidth: 256,
);
```

can reduce memory pressure before the image ever reaches the scene.

Performance starts before `paint()`.

## Stable frame math beats accidental giant timesteps

The `maxDelta` guard from [Building larger scenes](#building-larger-scenes) prevents one delayed frame from feeding a pathological timestep into ordinary motion code.

For deterministic physics, fixed-step simulation is a separate technique; clamping is not a replacement for it.

This is another performance theme worth keeping: **correct temporal behavior first, cleverness second.**

## Synthetic benchmarks answer narrow questions

A transform benchmark can tell you how transform traversal changed between commits.

A hit-test benchmark can tell you whether a pointer optimization regressed.

Neither automatically tells you whether *your application* feels smooth.

Engine-level benchmark scenarios belong in a repeatable benchmark suite, and any published numbers should travel with their scenario, hardware, build mode, and backend—not as one magic “GraphX is X fps” claim.

That is why this manual does not sprinkle synthetic numbers through every chapter. Benchmarks should become reproducible evidence, while the manual teaches how to choose and measure the right path.

## The useful optimization loop is boring

```text
build the clearest scene
        ↓
observe a real bottleneck
        ↓
measure the responsible subsystem
        ↓
change one structural choice
        ↓
measure again
```

That loop beats cargo-cult caching, flattening everything, or avoiding features because they sound expensive.

GraphX should make the straightforward version fast enough that optimization remains a response to evidence, not a prerequisite for drawing the first thing.
