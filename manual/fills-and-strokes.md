# Fills and strokes

Geometry answers *where*. A fill and a stroke answer *what should it look like?*

The usual pattern is to choose a style and then draw with it.

## A solid fill

The simplest fill is a color:

```dart
shape.graphics
    .beginFill(Colors.red)
    .drawCircle(0, 0, 40)
    .endFill();
```

`beginFill()` sets the current fill. Geometry drawn after it uses that fill until the style changes or you call `endFill()`.

That makes it easy to draw several pieces with the same paint:

```dart
shape.graphics
    .beginFill(Colors.orange)
    .drawCircle(30, 30, 20)
    .drawCircle(80, 30, 20)
    .endFill();
```

## Add an outline

A stroke begins with `lineStyle()`:

```dart
shape.graphics
    .lineStyle(4, Colors.black)
    .beginFill(Colors.yellow)
    .drawRoundRect(0, 0, 160, 70, 18)
    .endFill()
    .endStroke();
```

The first value is the line thickness, followed by the color.

Fill and stroke can be active at the same time, which is why the rounded rectangle gets both an inside color and an outline.

## A line without a fill

A stroke can stand on its own:

```dart
shape.graphics
    .lineStyle(3, Colors.blue)
    .moveTo(0, 0)
    .lineTo(120, 40)
    .endStroke();
```

Now the drawing behaves much more like picking up a pen: choose the line, move to a point, draw to the next one.

[Paths](#paths) takes that idea further.

## Changing style starts a new drawing group

You can change style as often as the drawing needs:

```dart
shape.graphics
    .beginFill(Colors.red)
    .drawCircle(0, 0, 30)
    .endFill()
    .beginFill(Colors.blue)
    .drawCircle(70, 0, 30)
    .endFill();
```

GraphX retains those styled pieces as part of the same `GGraphics` object.

You usually do not need to think about the internal batches. The useful mental model is simply: **set the style, draw the geometry that uses it, change the style when the drawing changes.**

## More than solid colors

`GGraphics` can also use gradients, textures, and shaders as fills.

For example, a linear gradient starts with `beginGradientFill()`:

```dart
shape.graphics
    .beginGradientFill(
      GGradientType.linear,
      [Colors.purple, Colors.blue],
    )
    .drawRoundRect(0, 0, 200, 90, 24)
    .endFill();
```

There are matching tools for gradient strokes and lower-level shader work too.

Those options are worth exploring when a drawing needs them. A solid `Colors.red` is still a perfectly good place to begin.
