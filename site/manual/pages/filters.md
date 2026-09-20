# Filters

Filters matter when the visual effect belongs to the **result of a subtree**, not to one primitive inside it.

Imagine a selected diagram object composed from vector geometry, a thumbnail, text, and connection markers. A glow around the final silhouette should not require every child to know how to glow. GraphX can render that branch first, then post-process the resulting pixels.

## One line can blur a whole subtree

```dart
selection.filters = [
  GBlurFilter(
    blurX: 6,
    blurY: 6,
  ),
];
```

The selection may contain shapes, images, text, nested groups, and descendants. The filter sees the rendered result rather than each primitive separately.

Assigning any filter makes `GCompositeMode.auto` isolate the subtree first because there must be pixels to filter.

## Shadows and glows do not care what produced the silhouette

```dart
selection.filters = [
  GDropShadowFilter(
    offsetX: 4,
    offsetY: 6,
    blurX: 8,
    blurY: 8,
    color: const Color(0x66000000),
  ),
];
```

A drop shadow is generated from the composited subtree alpha. Its silhouette comes from the final branch, regardless of which children produced those pixels.

GraphX currently provides:

```text
GBlurFilter
GDropShadowFilter
GGlowFilter
GOutlineFilter
GBevelFilter
GColorMatrixFilter
GShaderFilter
```

Drop shadows and glows can also be `inner`, which changes the effect from outside the silhouette to inside it.

## Filters are ordered

This is a filter chain:

```dart
node.filters = [
  GBlurFilter(blurX: 2, blurY: 2),
  GColorMatrixFilter(matrix),
];
```

Changing the order can change the picture because the output of one stage becomes the input to the next.

That is a good place to experiment rather than overthink it: blur-then-color and color-then-blur may look similar for some matrices and dramatically different for others.

## Filters are mutable objects

Keep a handle when an effect needs to animate:

```dart
final glow = GGlowFilter(
  blurX: 4,
  blurY: 4,
  color: Colors.cyan,
);

selection.filters = [glow];
```

Then later:

```dart
glow.setBlur(12, 12);
```

Changing a filter property tells its owning node to repaint; you do not need to replace the entire filter list every frame.

A `GFilter` instance belongs to one live node at a time. If two nodes need similar glows, give each node its own filter instance.

## The glow can extend past the bounds without changing the bounds

An outer glow or shadow visibly reaches beyond the original node geometry.

GraphX deliberately keeps canonical bounds and pointer hit testing unchanged. Composition expands only the temporary effect area needed to render the filter.

For tooling or inspection, ask for the visual effect extent explicitly:

```dart
final effectBounds = node.getEffectBounds();
```

That is different from `localBounds` because it answers a different question: **how far can the rendered effect reach?**

This is the same design philosophy we saw with custom hit areas. Geometry, interaction geometry, and final effect pixels do not need to be forced into one rectangle.

## Some filters are naturally more expensive than others

A blur or color matrix can map cleanly into a native linear image-filter chain.

Effects such as outer shadow, glow, outline, and bevel need branching/multi-pass composition because they combine an altered silhouette with the original source.

GraphX handles the compositor path for you, but the work still exists.

For a complicated filtered subtree whose pixels remain stable while the whole object moves around, the next chapter's raster cache can trade memory for less repeated effect work.

## Custom shader filters are backend-dependent

A `GShaderFilter` wraps Flutter's shader image-filter path:

```dart
if (GShaderFilter.isSupported) {
  node.filters = [GShaderFilter(shader)];
}
```

Flutter currently exposes that path only when the active backend supports shader image filters (notably Impeller). Check `isSupported` rather than assuming every target can run the same post-effect.

The rest of the scene does not need to know. A supported shader filter is still just another filter in the node's ordered chain.
