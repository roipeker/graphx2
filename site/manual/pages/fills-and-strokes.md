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

[Paths](#paths) takes that geometry further, while [Dashed and patterned lines](#dashed-and-patterned-lines) shows how a stroke itself can become retained repeating geometry.

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

By default, GraphX resolves that gradient against the retained path bounds. The default linear gradient runs from the center toward the right edge of that box.

So if the geometry changes size, the gradient naturally follows the geometry rather than staying pinned to some unrelated global rectangle.

## Control the gradient box when the artwork needs one shared space

Sometimes several shapes should use the same gradient coordinate box:

```dart
shape.graphics
    .beginGradientFill(
      GGradientType.linear,
      [Colors.orange, Colors.deepPurple],
      gradientBox: const Rect.fromLTWH(
        0,
        0,
        300,
        120,
      ),
    )
    .drawCircle(60, 60, 50)
    .drawCircle(220, 60, 50)
    .endFill();
```

Now both pieces sample the same local gradient box instead of each batch deriving its gradient only from its own geometry bounds.

The box is expressed in the `GGraphics` node's local drawing coordinates—the same coordinate system used by `drawCircle()`, `drawRect()`, `moveTo()`, and friends.

## Stops describe where colors land

```dart
shape.graphics.beginGradientFill(
  GGradientType.linear,
  [
    Colors.black,
    Colors.cyan,
    Colors.white,
  ],
  ratios: [0.0, 0.35, 1.0],
);
```

Those normalized `0..1` values say where each color lands along the gradient.

That should look familiar after [Mapping one range into another](#mapping-one-range-into-another): normalized progress is useful all over graphics because many visual systems can share the same compact `0..1` language.

## Linear, radial, and sweep are the same retained idea

```dart
GGradientType.linear
GGradientType.radial
GGradientType.sweep
```

all stay retained as part of the graphics style.

For a radial gradient, `begin` becomes the center alignment and `end` can act as the focal alignment. `radius` and `focalRadius` control the radial geometry.

For a sweep gradient, the start/end angles describe the angular range:

```dart
shape.graphics.beginGradientFill(
  GGradientType.sweep,
  [Colors.red, Colors.yellow, Colors.blue],
  sweepStartAngle: 0,
  sweepEndAngle: GMath.tau,
);
```

The angle vocabulary is the same one used by node rotation and [Angles, sine, and cosine](#angles-sine-and-cosine).

## Gradient strokes reuse the same model

Start the stroke first:

```dart
shape.graphics
    .lineStyle(8, Colors.white)
    .lineGradientStyle(
      GGradientType.linear,
      [Colors.pink, Colors.blue],
    )
    .moveTo(20, 40)
    .lineTo(280, 40)
    .endStroke();
```

`lineGradientStyle()` deliberately requires an active `lineStyle()` because it changes the brush of that retained stroke rather than creating a separate stroke width/cap/join definition.

## A low-level paint shader is still Flutter's shader

`GPaintShader` is a typedef for `dart:ui.Shader`.

So if Flutter/Canvas code already produced a native gradient/image shader, GraphX can retain it directly:

```dart
final shader = GGradient.linear(
  const Offset(0, 0),
  const Offset(200, 0),
  [Colors.purple, Colors.cyan],
);

shape.graphics
    .beginPaintShaderFill(shader)
    .drawRect(0, 0, 200, 80)
    .endFill();
```

`GGradient.linear()`, `.radial()`, and `.sweep()` are small backend-neutral constructors for those common native Canvas shaders.

That is different from the programmable `GShaderInstance` API in [Programmable shaders](#programmable-shaders). If you already have a GraphX fragment-shader instance, use:

```dart
shape.graphics
    .beginShaderFill(shaderInstance)
    .drawRect(0, 0, 200, 80)
    .endFill();
```

Uniform/sampler mutations on that retained shader instance request repaint without rebuilding the path geometry.

The hierarchy is therefore:

```text
solid color       → beginFill()
retained gradient → beginGradientFill()
native ui.Shader  → beginPaintShaderFill()
GShaderInstance   → beginShaderFill()
```

Use the highest-level form that already describes the visual you want. A solid `Colors.red` is still a perfectly good place to begin.
