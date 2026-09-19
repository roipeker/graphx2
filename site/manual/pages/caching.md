# Caching

Imagine a badge made from twelve paths, two text labels, an image, a glow, and a drop shadow.

Now move the whole badge across the screen.

If its internal pixels are not changing, redrawing every ingredient on every frame can be wasted work.

That is what the retained raster cache is for.

## Turn a subtree into reusable pixels

```dart
badge.cache.enabled = true;
```

GraphX renders the subtree into an owned texture. Once that cache is ready, the renderer can draw the cached texture instead of traversing and repainting the subtree's individual visuals.

The scene graph does **not** disappear. Children, transforms, lifecycle, input, and canonical geometry still exist. The cache replaces the rendering work, not the retained model.

This makes caching especially attractive when the internals are expensive but the cached node as a whole still moves, rotates, or scales. Those transforms are applied when GraphX draws the retained raster, so they do not dirty the cached pixels.

The cached node's own `alpha`, filters, mask, clip, color state, and descendant pixels are part of the captured result. Changing those invalidates the cache. An ancestor can still transform or fade the cached subtree without changing the raster itself.

## Cache stable pixels, not constantly changing pixels

A cached subtree is automatically invalidated when its rendered contents change.

If the cached node or one of its descendants changes color, text, graphics, alpha, filters, mask, or another paint-affecting property, GraphX marks containing raster caches dirty and rebuilds them when needed.

That correctness is convenient, but rebuilding a raster cache every frame defeats the reason to cache in the first place.

Good cache candidate:

```text
complex badge internals: stable
badge x/y/rotation: changing
```

Poor cache candidate:

```text
200 particles inside subtree: changing every frame
cache rebuilt every frame
```

The cache is a performance tool, not a magic “faster” switch.

## Resolution follows how large the cached object is rendered

By default GraphX chooses a raster scale from the node's effective world scale, render-view scale, and device pixel ratio.

That means a cached icon shown larger on a high-DPI screen can receive a higher-resolution backing texture instead of permanently looking like a blurry 1× screenshot.

Automatic scale is bounded by an internal memory budget, and GraphX uses hysteresis so small zoom changes do not continuously rebuild the cache.

You can pin the backing resolution explicitly:

```dart
badge.cache.scale = 2.0;
```

A fixed scale is an explicit request; use it when you actually know the resolution policy you want.

## Warm a cache before first display

Caching normally builds asynchronously when GraphX discovers it needs the raster.

When a first-frame transition must already have the cache prepared:

```dart
badge.cache.enabled = true;
await badge.cache.prepare();
```

`prepare()` can even run while a node is detached. Without an attached stage, automatic scale starts from a neutral 1× assumption and can be promoted later after attachment.

## Inspect what the cache is doing

The cache exposes a few useful diagnostics:

```dart
print(badge.cache.isReady);
print(badge.cache.isDirty);
print(badge.cache.isBuilding);
print(badge.cache.rasterScale);
print(badge.cache.pixelWidth);
print(badge.cache.pixelHeight);
print(badge.cache.captures);
```

Those are handy when a supposed optimization seems to keep rebuilding or uses more memory than expected.

Drop the retained raster without disabling the cache policy:

```dart
badge.cache.clear();
```

Or turn caching off entirely:

```dart
badge.cache.enabled = false;
```

## Filters are a classic cache win

A live shadow/glow/outline may require multiple compositor passes.

If the filtered subtree is visually stable, caching stores the **finished filtered result**. Future frames can reuse that raster until something inside invalidates it.

That is a very old 2D-engine optimization in spirit: spend once to flatten expensive stable artwork, then move the bitmap cheaply.

The trick is still the same decades later—measure the scene you actually have. Flattening thousands of rapidly changing pixels into another texture may cost more, not less.
