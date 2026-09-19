# Interpolation

You have a value here. You want it over there.

Interpolation answers the wonderfully practical question:

> what is the value somewhere between the two?

## `lerp` means “linear interpolation”

GraphX exposes the tiny formula through `GMath`:

```dart
final x = GMath.lerp(100, 300, 0.5);
```

The result is `200`.

The third value, usually called `t`, describes progress:

```text
t = 0.0  → start
t = 0.5  → halfway
t = 1.0  → end
```

So:

```dart
GMath.lerp(a, b, t)
```

really means:

```text
a + (b - a) × t
```

## Flutter already has `lerpDouble()`

It does, and using it is perfectly valid:

```dart
import 'dart:ui' as ui;

final x = ui.lerpDouble(100, 300, 0.5)!;
```

GraphX is not trying to replace Flutter's interpolation utility.

`dart:ui.lerpDouble()` is a general Flutter primitive. It accepts nullable `num?` endpoints and returns `double?`, which is useful in framework APIs where `null` can participate in interpolation.

`GMath.lerp()` is deliberately narrower:

```dart
double → double
```

and lives beside the scene-math helpers that tend to be used with it:

```text
clamp / invLerp / lerpClamped
lerpAngle / lerpCyclic
radians / degrees / wrapAngle
sin / cos / atan2 / hypo
```

That is the main reason this manual usually writes:

```dart
GMath.lerp(...)
```

The `GMath.` prefix makes a compact creative-coding toolbox discoverable from one place, and examples can move from interpolation to angle wrapping or distance math without changing mathematical vocabulary/imports.

If you are already in Flutter-centric code and `ui.lerpDouble()` reads more naturally, use it. For ordinary finite non-null scalar interpolation, both express the same idea. Their edge-case contracts are not identical—particularly around nullable values and non-finite numbers—so GraphX does not claim `GMath.lerp()` is simply an alias.

## Turn elapsed time into progress

Suppose a card should move from x=80 to x=360 in 0.6 seconds.

```dart
double elapsed = 0;
final duration = 0.6;
final fromX = 80.0;
final toX = 360.0;

@override
void update(double delta) {
  elapsed += delta;

  final t = GMath.clamp(elapsed / duration);
  x = GMath.lerp(fromX, toX, t);

  if (t >= 1.0) {
    updatesEnabled = false;
  }
}
```

There are two ideas hiding in there:

```text
elapsed / duration  → normalize time into 0..1
lerp(start, end, t) → map 0..1 into the value range
```

That pattern appears everywhere in animation.

## Linear motion is intentionally boring

A linear interpolation changes at a constant rate.

That is perfect for some things and robotic for others.

We can bend the progress value before passing it to `lerp`.

A tiny smoothstep curve is:

```dart
final eased = t * t * (3 - 2 * t);
final x = GMath.lerp(fromX, toX, eased);
```

The object starts gently, moves faster in the middle, and settles gently at the end.

The endpoints did not change. Only the mapping from **time → progress** changed.

That is the central idea behind easing functions.

## Flutter curves plug straight in

GraphX does not need to duplicate Flutter's easing catalog.

Flutter already ships a large set of `Curve`s:

```dart
import 'package:flutter/animation.dart';

final eased = Curves.easeOutCubic.transform(t);
final x = GMath.lerp(fromX, toX, eased);
```

The composition is clean:

```text
elapsed time
    ↓
normalize to t = 0..1
    ↓
Flutter Curve.transform(t)
    ↓
GMath.lerp(start, end, easedT)
```

That means familiar Flutter curves such as:

```dart
Curves.easeInOut
Curves.easeOutCubic
Curves.fastOutSlowIn
Curves.bounceOut
Curves.elasticOut
```

work perfectly well in GraphX motion code.

Some curves intentionally overshoot beyond `0..1`—`elasticOut`, for example. `GMath.lerp()` also permits extrapolation, so that overshoot naturally becomes motion beyond the endpoint before settling back.

The input to `Curve.transform()` should still be normalized to `0..1`:

```dart
final t = GMath.clamp(elapsed / duration);
final eased = Curves.elasticOut.transform(t);
```

There is therefore no need for GraphX core to clone every Flutter easing under new names just to animate retained nodes.

A future higher-level GraphX motion package can automate timing, cancellation, repeats, timelines, springs, and property binding while still building on these same small pieces: normalized progress, Flutter curves where they fit, and GraphX math/scene state where it adds value.

## Clamp when progress should stop at the endpoints

`GMath.lerp()` itself happily accepts values outside `0..1`:

```dart
GMath.lerp(0, 100, 1.2); // 120
```

Sometimes extrapolation is exactly what you want.

When it is not:

```dart
GMath.lerpClamped(0, 100, t);
```

clamps progress before interpolating.

## `invLerp` asks the opposite question

If `lerp` asks:

> where is 30% between A and B?

then `invLerp` asks:

> what percentage is this value between A and B?

```dart
final t = GMath.invLerp(100, 300, 160);
```

`t` is `0.3`.

That is handy for sliders, scroll progress, normalizing sensor values, mapping a position into a color gradient, or turning any arbitrary range back into the familiar `0..1` space.

## Angles have a trap at the wrap point

Suppose one angle is 350° and another is 10°.

A naïve numerical lerp sees a 340° difference and rotates the long way around.

GraphX can interpolate the shortest angular path:

```dart
final angle = GMath.lerpAngle(
  GMath.radians(350),
  GMath.radians(10),
  t,
);
```

`lerpAngle()` uses normalized angular difference so the motion crosses through 0° instead of spinning almost a full revolution backwards.

That tiny detail matters constantly in steering, turrets, dials, cameras, and rotating UI.

## Interpolation is not a tween system

These helpers are math primitives. They do not own time, schedule updates, cancel animations, sequence timelines, or decide lifecycle for you.

That is deliberate in this chapter.

First learn the reusable idea:

```text
time → normalized progress → optional easing → interpolated value
```

Then a higher-level motion/tween API—whether GraphX core or an ecosystem package—becomes much easier to understand because it is automating something you already recognize.

> **Go play with easing:** [Easings.net](https://easings.net/) puts the common easing families side-by-side so you can *see* the motion shape before choosing one. Flutter's `Curves` names will feel very familiar after a few minutes there.
