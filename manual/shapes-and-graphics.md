# Shapes and graphics

Sometimes the easiest way to make a visual is simply to draw it.

A rectangle, a circle, a path, a little icon, a debug overlay — not everything needs to start life as an image asset.

That is what `GShape` and `GGraphics` are for.

## A shape owns a drawing

Create a shape and add it to the scene:

```dart
final shape = root.addChild(GShape());
```

Every `GShape` has a `graphics` object:

```dart
shape.graphics
    .beginFill(Colors.orange)
    .drawCircle(0, 0, 40)
    .endFill();
```

You can think of `graphics` as a small drawing surface attached to that node.

Pick a fill or stroke, move the pen when you need to, draw some geometry, and keep going.

## Familiar like a canvas, retained like GraphX

If you have used Flutter's `Canvas`, some of the vocabulary will feel familiar: fills, lines, paths, circles, rectangles, curves.

There is one important difference.

A Flutter `Canvas` is normally something you draw into during a paint pass. `GGraphics` keeps the geometry you give it.

```dart
shape.graphics.drawCircle(0, 0, 40);
```

That circle remains part of the shape until you change or clear the graphics. You do not need to issue the same drawing command every frame just because the shape moved.

Move the node instead:

```dart
shape.setPosition(200, 140);
shape.rotation = 0.3;
shape.scale = 1.2;
```

The retained drawing comes along for the ride.

## The built-in shapes

For common geometry, `GGraphics` has direct helpers:

```dart
shape.graphics.drawRect(0, 0, 120, 60);
shape.graphics.drawRoundRect(0, 0, 120, 60, 16);
shape.graphics.drawCircle(60, 30, 30);
shape.graphics.drawEllipse(60, 30, 50, 24);
```

There are also helpers for lines, polygons, arcs, paths, and more specialized rounded rectangles.

Do not worry about memorizing the list. The common shapes are there so simple drawings stay simple; paths are there when you want to build something more freely.

## Drawing commands can be chained

Most `GGraphics` drawing and style methods return the same `GGraphics` instance.

That is why this reads naturally:

```dart
shape.graphics
    .beginFill(Colors.blue)
    .drawRoundRect(0, 0, 180, 80, 20)
    .endFill();
```

This is ordinary method chaining, not Dart cascade syntax. The fluent API is intentional: a short drawing often reads better as one sequence.

## One `GShape` can hold several drawings

A single `GShape` can hold more than one piece of geometry:

```dart
shape.graphics
    .beginFill(Colors.blue)
    .drawCircle(0, 0, 40)
    .endFill()
    .beginFill(Colors.white)
    .drawCircle(0, 0, 12)
    .endFill();
```

Now both circles belong to the same shape and share the same node transform.

If the pieces need to move or react independently, that is usually a sign they should be separate nodes instead.

## `clear()` removes the retained drawing

`clear()` removes the retained drawing:

```dart
shape.graphics.clear();
```

For graphics that are intentionally rebuilt, `redraw()` is a convenient way to clear and draw as one operation:

```dart
shape.graphics.redraw((graphics) {
  graphics
      .beginFill(Colors.green)
      .drawCircle(0, 0, radius)
      .endFill();
});
```

That is useful for geometry that genuinely changes shape.

For ordinary movement, rotation, scale, or alpha, leave the geometry alone and transform the node. That is both simpler to read and closer to how GraphX is designed to work.

Next we can give the pen some character with [Fills and strokes](#fills-and-strokes).
