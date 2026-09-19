# Dashed and patterned lines

A line does not have to be one uninterrupted stroke.

It can be a road marking, a selection marquee, tiny arrows following a curve, dots around a circle, or a repeating decorative motif.

GraphX keeps those patterns as retained stroke geometry rather than asking you to manually place dozens of little nodes.

## Start with ordinary dashes

Choose a stroke first, then add a dash pattern:

```dart
shape.graphics
    .lineStyle(3, Colors.cyan)
    .lineDash([12, 8])
    .moveTo(20, 40)
    .lineTo(280, 40)
    .endStroke();
```

The values alternate:

```text
12 painted
 8 gap
12 painted
 8 gap
...
```

They are measured in the path's local scene units.

An odd-length list is repeated once internally so it still forms a paint/gap cycle.

## Phase slides the pattern along the path

```dart
shape.graphics
    .lineStyle(3, Colors.white)
    .lineDash(
      [10, 6],
      phase: 8,
    )
    .drawCircle(100, 100, 70)
    .endStroke();
```

`phase` shifts where the dash cycle begins.

That is useful when two otherwise-identical dashed lines need a different visual offset.

`lineDash()` stores that per-use phase in the retained stroke batch. For a continuously animated decorative line, `GLinePattern` gives you a more convenient mutable phase handle.

## Stamp a tiny drawing along another path

First author the motif as a normal Dart `Path`:

```dart
final arrow = Path();
arrow.moveTo(-7, -4);
arrow.lineTo(2, 0);
arrow.lineTo(-7, 4);
arrow.close();
```

Turn it into a reusable line pattern:

```dart
final arrows = GLinePattern(
  arrow,
  advance: 22,
  filled: true,
  pivot: GPoint(0, 0),
);
```

Then apply it to retained GraphX path geometry:

```dart
shape.graphics
    .lineStyle(2, Colors.orange)
    .linePattern(arrows)
    .moveTo(30, 180)
    .curveTo(
      160, 20,
      300, 180,
    )
    .endStroke();
```

GraphX samples the source path and stamps the arrow motif repeatedly along it.

The active line brush supplies the motif color. With `filled: true`, the motif path is filled; otherwise it is stroked.

## Tangent alignment makes motifs follow the curve

The default is:

```dart
GLinePatternAlignment.tangent
```

Each motif rotates to follow the local path direction.

So arrows naturally point along a Bézier curve without you calculating each angle yourself.

If the motif should keep one fixed orientation instead:

```dart
final dots = GLinePattern(
  motif,
  advance: 18,
  alignment: GLinePatternAlignment.fixed,
);
```

Fixed alignment is useful for things such as upright ticks or repeated symbols that should not rotate with the path.

## `pivot` decides what part of the motif sits on the path

Suppose an arrow was authored around its center, but you want the arrow tip exactly on the sampled curve.

Choose that authored point as the pivot:

```dart
final pattern = GLinePattern(
  arrow,
  advance: 22,
  pivot: GPoint(2, 0),
  filled: true,
);
```

GraphX places that pivot on each sampled path point.

This is the same registration-point idea we already know from node pivots, applied to tiny repeated vector geometry.

## Rotate the authored motif without changing its path

If the motif's natural “forward” direction was drawn vertically rather than toward +X:

```dart
final pattern = GLinePattern(
  motif,
  advance: 20,
  rotation: GMath.halfPi,
);
```

That authored rotation is added after tangent alignment.

It is often easier to fix orientation once here than to redraw the motif geometry around another axis.

## Animate the motif phase

`GLinePattern.phase` is retained mutable state:

```dart
root.onUpdate.add((delta) {
  arrows.phase += 60 * delta;
});
```

The arrows now travel forward along the path.

GraphX invalidates only the generated motif geometry and requests repaint for graphics using that pattern. The original source path and its retained path-metric snapshot do not need to be rebuilt just because phase moved.

That makes effects such as these pleasantly small:

```text
flow direction arrows
marching route markers
animated cables/pipes
motion-path previews
selection ornaments
```

## One pattern can drive several paths

A `GLinePattern` can be reused:

```dart
routeA.graphics.linePattern(arrows);
routeB.graphics.linePattern(arrows, phase: 8);
```

Changing:

```dart
arrows.phase += 1;
```

updates every `GGraphics` currently watching that shared pattern.

The per-use `phase` is added on top, so two routes can share one moving pattern while keeping different offsets.

## Closed loops avoid an ugly seam

A naïve repeated motif around a circle often produces one awkward problem: the final symbol lands too close to the first, or disappears as phase moves across the path seam.

For closed contours, GraphX chooses the nearest integral motif count and distributes the spacing uniformly around the loop.

That keeps phase animation continuous through the closure rather than creating a duplicate/disappearing seam motif.

It is a small renderer detail, but it is the difference between a circle of arrows that feels intentional and one with a visibly broken join.

## Patterns are geometry, not child nodes

A hundred arrowheads produced by `linePattern()` are not a hundred `GNode`s.

They do not have independent pointer input, lifecycle, transforms, or children. They are generated retained path geometry belonging to the `GGraphics` stroke.

That is exactly why the feature is useful.

If every repeated item needs independent behavior, use real scene objects. If the repetition is simply how a line should look, keep it in the line.
