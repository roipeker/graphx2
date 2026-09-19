# Mapping one range into another

The pointer moves from `0` to `800` pixels across a view.

You want opacity to move from `0` to `1`.

Or distance from `0..300` should become blur from `20..0`.

Or a slider from `20..420` should control rotation from `-π..π`.

That is the same operation every time: **map one range into another.**

## First turn the input into `0..1`

Suppose the pointer X coordinate lives between `100` and `500`:

```dart
final t = GMath.invLerp(
  100,
  500,
  pointerX,
);
```

Now:

```text
pointerX = 100 → t = 0
pointerX = 300 → t = 0.5
pointerX = 500 → t = 1
```

`invLerp` means **inverse interpolation**.

Instead of asking:

> what value is 30% between A and B?

it asks:

> what percentage of the way from A to B is this value?

That normalized `0..1` space is incredibly useful because almost every other interpolation tool understands it.

## Then expand `0..1` into the output range

Turn the same pointer position into alpha:

```dart
final alpha = GMath.lerp(0, 1, t);
```

or scale:

```dart
final scale = GMath.lerp(0.7, 1.3, t);
```

or angle:

```dart
final rotation = GMath.lerp(
  -GMath.pi,
  GMath.pi,
  t,
);
```

The complete recipe is:

```text
input range
    ↓ invLerp
0..1
    ↓ lerp
output range
```

That is all “remapping” means.

## Pointer position → opacity

```dart
final t = GMath.invLerp(
  0,
  stage.width,
  stage.pointer.x,
);

card.alpha = GMath.lerpClamped(
  0.1,
  1.0,
  t,
);
```

Move right and the card becomes more opaque.

The `Clamped` part matters when the input may go outside the intended range.

Without clamping, interpolation can extrapolate beyond the endpoints.

## Distance → effect strength

Suppose a glow should be strongest near the pointer and disappear 300 pixels away.

```dart
final dx = pointerX - node.x;
final dy = pointerY - node.y;
final distance = GMath.hypo(dx, dy);

final t = GMath.clamp(
  GMath.invLerp(0, 300, distance),
);

final glow = GMath.lerp(18, 0, t);
```

Notice the output range runs **backwards**:

```text
near  → t 0 → glow 18
far   → t 1 → glow 0
```

`lerp` does not care whether the end is larger or smaller than the start.

## A slider is just a range conversion

A horizontal slider thumb might live between x=40 and x=340:

```dart
final t = GMath.clamp(
  GMath.invLerp(40, 340, thumb.x),
);
```

Turn that into volume:

```dart
final volume = GMath.lerp(0, 1, t);
```

or a temperature range:

```dart
final temperature = GMath.lerp(16, 30, t);
```

or a frame index:

```dart
final frame = GMath.floor(
  GMath.lerp(0, sequence.frameCount, t),
).toInt();
```

For discrete values, decide deliberately how the continuous value should round/clamp at the edges.

## Mapping is also a debugging superpower

Suppose a simulation value naturally lives around `-250..900`, but you want to inspect it as a bar from `0..200` pixels:

```dart
final t = GMath.invLerp(-250, 900, value);
final width = GMath.lerpClamped(0, 200, t);
```

You have turned an awkward domain value into something visually inspectable.

Creative coding is full of this kind of translation:

```text
sound amplitude → scale
speed → color
scroll → rotation
distance → opacity
pressure → line width
time → progress
progress → anything else
```

Once you recognize “range in, range out,” the code becomes much less magical.

## Why GraphX does not currently have `GMath.map()`

A dedicated remap helper could make this one line:

```text
map(value, fromMin, fromMax, toMin, toMax)
```

GraphX² does not currently expose that API.

For now, composing `invLerp()` + `lerp()` keeps both conceptual steps visible and uses primitives that are useful independently.

This repeated pattern is also exactly the kind of thing worth evaluating later when `GMath` grows: a helper should earn its place because people keep writing the same meaningful operation, not merely because another math library has one.

## Reversing the range needs no special case

Fade out as distance increases:

```dart
final alpha = GMath.lerp(1, 0, t);
```

Rotate clockwise as a slider moves right:

```dart
final angle = GMath.lerp(
  GMath.halfPi,
  -GMath.halfPi,
  t,
);
```

The direction of the output range is just data.

No separate “reverse mapping” API is needed.

## Normalize once, reuse everywhere

If several visual properties respond to the same input, compute `t` once:

```dart
final t = GMath.clamp(
  GMath.invLerp(0, stage.width, pointerX),
);

card.alpha = GMath.lerp(0.2, 1.0, t);
card.scale = GMath.lerp(0.8, 1.2, t);
card.rotation = GMath.lerp(
  -0.2,
  0.2,
  t,
);
```

Now three effects share one normalized explanation of the input.

That tends to produce both cleaner code and more coherent motion.
