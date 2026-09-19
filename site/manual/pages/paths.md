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

## Underneath, it is Dart's `Path`

GraphX does not invent a separate vector-path format here. The retained geometry inside `GGraphics` is built on Flutter/Dart's native `Path` from `dart:ui`.

That means calls such as:

```dart
shape.graphics
    .moveTo(20, 20)
    .lineTo(140, 20)
    .curveTo(100, 0, 180, 100);
```

ultimately build the same kind of path geometry you may already know from Flutter `Canvas` drawing. GraphX keeps that path around as retained scene geometry instead of asking you to recreate it every paint pass.

This is also useful in the other direction: if you already have a Dart `Path`, you can draw it directly into `GGraphics`:

```dart
final path = Path();
path.moveTo(0, 0);
path.lineTo(80, 0);
path.lineTo(40, 70);
path.close();

shape.graphics
    .beginFill(Colors.orange)
    .drawPath(path)
    .endFill();
```

`drawPath()` adds the supplied `Path` into GraphX's retained graphics geometry. So existing Flutter path-building knowledge carries over naturally.

One detail worth keeping in mind: GraphX may split a drawing into multiple retained batches when styles change, and each batch owns its own native `Path`. You normally do not need to think about those batches unless you are profiling or inspecting graphics internals.

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
