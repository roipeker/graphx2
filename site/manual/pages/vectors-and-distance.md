# Vectors and distance

A vector is just an arrow described by two numbers.

In 2D:

```text
(dx, dy)
```

Those two numbers can mean **direction**, **velocity**, **acceleration**, or simply “how far from here to there.” The math is the same; the meaning comes from how you use it.

> **Why not `Vec2()` everywhere?** You will notice this manual often keeps vector math as plain `x` / `y`, `dx` / `dy`, or `velocityX` / `velocityY`. That is partly pedagogical—the arithmetic stays visible instead of disappearing behind methods—and partly GraphX lineage. A lot of Flash/ActionScript creative-coding code used this wonderfully direct scalar style, and GraphX still feels at home there. Wrapping two numbers in an object is not automatically clearer. `GPoint` is available when a reusable mutable point/container helps, and a richer vector abstraction can earn its place once code repeatedly needs operations such as normalization, dot products, reflection, or projection. For `x += velocityX * delta`, plain variables are often exactly enough.

## From one point to another

Suppose a ship is here:

```dart
final shipX = 80.0;
final shipY = 120.0;
```

and the pointer is here:

```dart
final pointerX = 260.0;
final pointerY = 180.0;
```

The vector from ship to pointer is:

```dart
final dx = pointerX - shipX;
final dy = pointerY - shipY;
```

That pair answers two questions at once:

```text
how far horizontally?
how far vertically?
```

It is already a direction toward the pointer, but its length depends on how far away the pointer is.

## Length is Pythagoras in useful clothing

The vector length is:

```dart
final length = GMath.hypo(dx, dy);
```

which is the familiar:

```text
sqrt(dx² + dy²)
```

If `dx = 3` and `dy = 4`, the length is 5.

That old 3-4-5 triangle turns out to be everywhere in graphics. [Why Pythagoras keeps showing up](#why-pythagoras-keeps-showing-up) collects the same idea across distance, speed, normalization, diagonal movement, and collision.

Distance between two scene points is the length of the vector between them.

## Normalize when you want direction without distance

A vector pointing toward the target might be `(180, 60)`.

That direction is useful, but its length is not 1.

Normalize it:

```dart
final length = GMath.hypo(dx, dy);

if (length > GMath.epsilon) {
  final nx = dx / length;
  final ny = dy / length;
}
```

Now `(nx, ny)` points the same way but has length 1.

That is a **unit vector**.

Multiply it by whatever magnitude you actually need:

```dart
final vx = nx * speed;
final vy = ny * speed;
```

or:

```dart
final offsetX = nx * 24;
final offsetY = ny * 24;
```

Direction and magnitude are now separate knobs.

## Move toward a target at constant speed

```dart
@override
void update(double delta) {
  final dx = targetX - x;
  final dy = targetY - y;
  final distance = GMath.hypo(dx, dy);

  if (distance <= GMath.epsilon) return;

  final step = speed * delta;
  if (step >= distance) {
    setPosition(targetX, targetY);
    return;
  }

  x += dx / distance * step;
  y += dy / distance * step;
}
```

The `step >= distance` check prevents the node from overshooting and oscillating around a nearby target.

This is not easing. The object moves at constant speed until it arrives.

## Sometimes you do not need the square root

If all you want to know is whether two points are within a radius, compare **squared distance**.

`GPoint` has a helper for that:

```dart
final a = GPoint(player.x, player.y);
final b = GPoint(enemy.x, enemy.y);

final near = a.distanceSquaredTo(b) < 100 * 100;
```

Why square the radius instead of taking the square root of the distance?

Because this comparison:

```text
distance² < radius²
```

answers the same yes/no question without computing `sqrt()`.

That matters most inside hot loops with many proximity checks, not for one occasional distance calculation.

## `GPoint` is storage, not a giant vector algebra API

GraphX uses `GPoint` as a small mutable 2D geometry object:

```dart
final point = GPoint();
point.set(20, 40);
```

It is intentionally useful for output/reuse paths such as coordinate transforms without forcing every temporary point to allocate a Flutter `Offset`. [GPoint or Offset?](#gpoint-or-offset) explains that engine/Flutter geometry boundary directly.

But GraphX does not pretend `GPoint` is a complete physics-vector framework.

When you are learning or writing a small piece of motion code, `dx` / `dy` are often clearer than wrapping every operation in vector methods.

If an ecosystem package later needs richer vector algebra, it can build that abstraction without changing the core meaning of scene coordinates.

## Angle and vector are two views of the same direction

From the previous chapter:

```dart
final dx = GMath.cos(angle);
final dy = GMath.sin(angle);
```

turns an angle into a unit direction.

And:

```dart
final angle = GMath.atan2(dy, dx);
```

turns a direction back into an angle.

That round trip is worth remembering:

```text
angle ⇄ direction vector
```

Once that feels natural, steering, orbiting, aiming, normals, and path tangents stop looking like separate tricks. They are variations on the same 2D geometry.

> **Go deeper:** Daniel Shiffman's free [Nature of Code — Vectors](https://natureofcode.com/vectors/) chapter is an excellent creative-coding continuation: interactive examples turn magnitude, normalization, velocity, and acceleration into things you can actually watch move.
