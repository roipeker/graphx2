# When numbers wrap around

`359°` and `1°` look far apart if you treat them like ordinary numbers.

On a circle they are only `2°` apart.

That is the basic problem with **cyclic values**: the end connects back to the beginning.

## `wrap()` keeps a value inside one cycle

For degrees:

```dart
final angle = GMath.wrap(degrees, 360);
```

Examples:

```text
370  → 10
720  → 0
-10  → 350
```

For a generic period:

```dart
final phase = GMath.wrap(time, duration);
```

Now `phase` always lives within one duration cycle.

This is the arithmetic behind looped animation, clocks, repeating textures, circular meters, hue, and world wrapping.

## Loop progress cleanly

One cycle every 1.5 seconds:

```dart
final duration = 1.5;
final localTime = GMath.wrap(stage.elapsed, duration);
final t = localTime / duration;
```

`t` repeatedly travels through `0..1`.

Then:

```dart
rotation = t * GMath.tau;
```

loops forever without resetting `stage.elapsed` itself.

## Wrap a world position

For an arcade-style horizontal world:

```dart
x = GMath.wrap(x, worldWidth);
```

Move past the right edge and you reappear at the left.

Move left below zero and you wrap back near the right.

For a sprite with visible width, you may intentionally wrap relative to an expanded range so it disappears fully before re-entering. The math still uses the same cyclic idea; the chosen interval simply changes.

## Angles deserve specialized helpers

GraphX provides:

```dart
GMath.wrapAngle(angle)
```

for the canonical `0..τ` representation.

And:

```dart
GMath.normalizeAngle(angle)
```

for an equivalent angle around `-π..π`.

That second form is especially useful when you care about **signed shortest rotation**.

## The shortest angular difference crosses the seam

```dart
final from = GMath.radians(350);
final to = GMath.radians(10);

final delta = GMath.deltaAngle(from, to);
```

The useful answer is roughly:

```text
+20°
```

not:

```text
-340°
```

The numeric seam at `0/360` should not force an object to take the long way around the circle.

That is why ordinary subtraction is not enough for cyclic values.

## `lerpAngle()` uses that shortest difference

```dart
final rotation = GMath.lerpAngle(
  from,
  to,
  t,
);
```

The interpolation crosses the wrap boundary naturally.

This is useful for:

```text
turrets
compass needles
camera heading
steering
rotating UI
```

where “shortest turn” is usually what the eye expects.

## Cyclic interpolation is not only for angles

`GMath.lerpCyclic()` takes any period:

```dart
final hue = GMath.lerpCyclic(
  350,
  10,
  t,
  360,
);
```

Now hue moves through red across the `360 → 0` seam instead of sweeping backwards through almost the entire color wheel.

Another example: hours on a 24-hour clock:

```dart
final hour = GMath.lerpCyclic(
  23,
  1,
  t,
  24,
);
```

The shortest route crosses midnight.

## Ordinary lerp still has a place

Sometimes you **want** the long way around.

Maybe a dial should deliberately spin a full revolution before landing.

Then ordinary interpolation is the correct tool:

```dart
final rotation = GMath.lerp(
  start,
  start + GMath.tau,
  t,
);
```

Cyclic helpers encode a particular semantic choice: values live on a loop and the shortest connection is desired.

Do not use them merely because the value happens to be an angle.

## Wrap is different from clamp

Clamp says:

```text
below min → stay at min
above max → stay at max
```

Wrap says:

```text
past the end → continue from the beginning
before the beginning → continue from the end
```

So:

```dart
GMath.clamp(1.2) // 1.0
GMath.wrap(1.2, 1.0) // 0.2
```

Those are completely different behaviors even though both “keep a number in a range.”

Once you recognize cyclic quantities, a lot of awkward edge-case code disappears into one well-defined operation.
