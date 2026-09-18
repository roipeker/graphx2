# Paths

Primitive shapes are convenient until you want a shape that is not already on the menu.

Then it is time to move the pen yourself.

## Start somewhere

A path normally begins with `moveTo()`:

```dart
shape.graphics.moveTo(20, 20);
```

Nothing is drawn yet. You have simply placed the pen.

Now draw a line:

```dart
shape.graphics.lineTo(140, 20);
```

And another:

```dart
shape.graphics.lineTo(80, 120);
```

Close the path and you have a triangle:

```dart
shape.graphics.closePath();
```

With a fill around it:

```dart
shape.graphics
    .beginFill(Colors.orange)
    .moveTo(20, 20)
    .lineTo(140, 20)
    .lineTo(80, 120)
    .closePath()
    .endFill();
```

This is probably the most literal version of the pen analogy in `GGraphics`.

## Curves

Straight lines only get us so far.

`curveTo()` adds a quadratic Bézier curve using one control point and an ending point:

```dart
shape.graphics
    .moveTo(20, 100)
    .curveTo(100, 0, 180, 100);
```

`cubicCurveTo()` gives you two control points:

```dart
shape.graphics
    .moveTo(20, 100)
    .cubicCurveTo(
      60, 0,
      140, 0,
      180, 100,
    );
```

If Bézier control points do not feel intuitive yet, that is completely fine. They are much easier to understand when you can see and drag them, so we will eventually give curves their own visual lesson.

## Arcs and polygons

There are helpers when constructing the path point by point would only add noise:

```dart
shape.graphics.arc(
  100,
  100,
  60,
  0,
  GMath.pi,
);
```

`dart:math` would work here too. `GMath.pi` is simply convenient when the rest of the code is already using GraphX.

and:

```dart
shape.graphics.drawPolygon(points);
```

The goal is not to force everything through `moveTo()` and `lineTo()`. Use the representation that makes the geometry easiest to understand.

## Paths stay with the shape

Just like the primitive drawing helpers, path geometry is retained.

Once you have drawn a curve, moving its `GShape` does not rebuild the curve:

```dart
shape.setPosition(240, 180);
shape.rotation += 0.1;
```

The path stays local to the shape and the node transform places it in the scene.

That separation — geometry local to the object, transform placing the object — is one of the ideas that keeps coming back throughout GraphX.
