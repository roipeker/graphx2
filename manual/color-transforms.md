# Color transforms

A spaceship gets hit.

For 80 milliseconds you want the **whole ship**—body, windows, decals, children—to flash red.

You could redraw every primitive with temporary colors.

Or you can transform the color of the subtree that already exists.

## Tint multiplies the existing RGB

```dart
ship.tint = Colors.red;
```

`tint` is a shortcut for a multiplicative `GColorTransform` inherited by the node and its descendants.

Conceptually:

```text
source red   × tint red
source green × tint green
source blue  × tint blue
```

That means tint preserves some of the source artwork's shading.

A white highlight tinted red becomes red. A dark shadow remains dark.

Clear it with:

```dart
ship.tint = null;
```

## `colorize` replaces visible RGB

Sometimes you want a silhouette rather than a tint:

```dart
ship.colorize = Colors.red;
```

`colorize` replaces visible RGB with the chosen color while preserving the source alpha silhouette.

That makes it useful for things such as:

```text
hit flash
team-color silhouette
locked/disabled icon treatment
single-color map markers
```

The color's alpha also multiplies source alpha.

Clear it the same way:

```dart
ship.colorize = null;
```

## The transform belongs to the hierarchy

Put the transform on a parent:

```dart
enemyGroup.tint = Colors.blue;
```

and descendants inherit it.

A child can also have its own local color transform. GraphX combines parent and local transforms as the subtree is rendered.

That is the color equivalent of transform hierarchy:

```text
parent color transform
        ↓
child color transform
        ↓
source pixels
```

You do not have to push the same color change into every descendant manually.

## Resolved paint state is not the same as compositing a subtree

There are two very different ways a renderer can apply color/alpha state.

The cheap/direct idea is:

```text
parent alpha + color transform
          ↓
resolve inherited render state
          ↓
each primitive paints with that state
```

GraphX prefers this path when the renderable can consume the state directly.

For example, graphics, images, image batches, and shader nodes can apply inherited alpha/color filtering through their own paint submission. The subtree does **not** need to become a temporary image merely because a parent has a tint or alpha multiplier.

That is different from:

```text
render complete subtree normally
          ↓
store it in an offscreen layer
          ↓
apply opacity / filter to the finished pixels
          ↓
composite that layer back
```

The second operation needs `Canvas.saveLayer()` semantics because the effect is being applied to a finished group of pixels rather than to each primitive as it draws.

That distinction is critical for both appearance and cost.

## Some primitives need a bounded fallback layer

Not every Flutter rendering primitive exposes a way to inject GraphX's inherited paint state directly.

`GText`, for example, is backed by an already-built `ui.Paragraph`. When inherited alpha/color-transform state needs to affect that paragraph, GraphX wraps just the paragraph bounds in a small render-state layer and applies the state on restore.

`GIcon` has the same kind of fallback because it also relies on retained text/glyph rendering.

So the rule is not:

```text
GColorTransform never uses saveLayer()
```

It is:

```text
apply inherited state directly when the primitive supports it
otherwise isolate the smallest practical bounds as a fallback
```

That is much cheaper than automatically compositing an entire parent subtree just because some inherited color state exists.

## Alpha and color are related but separate

Ordinary node alpha still exists:

```dart
ship.alpha = 0.5;
```

A color transform can also contain an `alphaMultiplier`, but the common `tint` shortcut deliberately leaves hierarchy alpha alone.

That keeps two frequent intentions readable:

```dart
ship.tint = Colors.red; // change RGB treatment
ship.alpha = 0.5;       // fade the node hierarchy
```

When you genuinely need a full transform, use `GColorTransform`:

```dart
ship.colorTransform = const GColorTransform(
  redMultiplier: 1.0,
  greenMultiplier: 0.7,
  blueMultiplier: 0.7,
  alphaMultiplier: 0.9,
  redOffset: 20,
);
```

The offsets use `0..255` channel units, following the familiar Flash `ColorTransform` / Flutter color-matrix convention.

## Why both multipliers and offsets?

A multiplier scales what was already there:

```text
newRed = oldRed × multiplier
```

An offset adds light regardless of the original channel:

```text
newRed = oldRed × multiplier + offset
```

Together they cover a surprisingly broad set of cheap color effects without rebuilding source geometry or textures.

For imported/animated transforms where allocations matter, GraphX also exposes:

```dart
node.setColorTransformValues(
  redMultiplier,
  greenMultiplier,
  blueMultiplier,
  alphaMultiplier,
  redOffset,
  greenOffset,
  blueOffset,
  alphaOffset,
);
```

Most hand-written scene code will be clearer with `tint`, `colorize`, or a `GColorTransform` value.

## This is not the same as a color-matrix filter

A node color transform is inherited render state. GraphX combines parent/local transforms and, where possible, pushes the resolved result into each primitive's own paint path.

`GColorMatrixFilter` is more general: every output channel may depend on every input channel through a full 4×5 matrix.

More importantly, it is a **post-processing filter over the node subtree**. GraphX therefore needs the subtree as pixels first, which means isolation/compositing rather than merely resolving inherited state into primitive paints.

Use the smaller tool when the smaller tool expresses the effect:

```text
tint / colorize / per-channel transform
        → GColorTransform

cross-channel color grading / arbitrary matrix
        → GColorMatrixFilter
```

The difference is not only API shape; it changes how much compositing work the renderer needs to do.
