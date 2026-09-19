# Animation patterns

By now we have all the ingredients for animation: frame updates, `delta`, interpolation, angles, and springs.

This chapter is less theory and more **small recipes worth stealing**.

## Keep local time when the animation should restart

`stage.elapsed` is great for scene-wide time.

A self-contained animation often wants its own clock:

```dart
double time = 0;

@override
void update(double delta) {
  time += delta;
}
```

Reset it whenever the animation restarts:

```dart
void replay() {
  time = 0;
  updatesEnabled = true;
}
```

That keeps this object's animation independent of how long the stage has existed.

## Loop from 0 to 1

Suppose one cycle lasts 1.5 seconds:

```dart
final duration = 1.5;
final t = GMath.wrap(time, duration) / duration;
```

`t` repeatedly travels through:

```text
0 → 1 → 0 → 1 → ...
```

Use it anywhere normalized progress is convenient:

```dart
rotation = t * GMath.tau;
```

Now the node completes one full revolution per cycle.

## Ping-pong without reversing a timeline

For motion that travels there and back:

```dart
final phase = GMath.wrap(time / duration, 2.0);
final t = phase <= 1.0 ? phase : 2.0 - phase;

x = GMath.lerp(leftX, rightX, t);
```

`t` becomes:

```text
0 → 1 → 0 → 1 → ...
```

That is enough for:

```text
patrolling enemies
breathing UI
scanner lines
floating labels
back-and-forth camera motion
```

Nothing had to “reverse.” We simply folded a repeating phase back onto itself.

## Pulse with sine

A sine wave is already a smooth repeating motion:

```dart
final frequency = 2.0; // cycles per second
final wave = GMath.sin(time * frequency * GMath.tau);
```

`wave` moves between `-1` and `1`.

Turn that into a subtle scale pulse:

```dart
scale = 1.0 + wave * 0.08;
```

or alpha:

```dart
alpha = 0.75 + wave * 0.25;
```

If you need a `0..1` wave instead:

```dart
final pulse = 0.5 + wave * 0.5;
```

That tiny remapping appears constantly in procedural animation.

## Animate several properties from one progress value

A transition usually feels more coherent when related properties share one `t`:

```dart
final t = GMath.clamp(time / 0.4);
final eased = t * t * (3 - 2 * t);

x = GMath.lerp(40, 180, eased);
alpha = GMath.lerp(0, 1, eased);
scale = GMath.lerp(0.8, 1.0, eased);
```

Now position, opacity, and scale arrive together rather than running three unrelated clocks.

This is essentially what a higher-level tween system eventually automates: time bookkeeping + easing + property interpolation.

Understanding the small version first makes the larger abstraction much less mysterious.

## A tiny hand-written sequence

Sometimes two or three beats are easier to express directly than by building a timeline system.

For example: enter, hold, fade:

```dart
@override
void update(double delta) {
  time += delta;

  if (time < 0.35) {
    final t = GMath.clamp(time / 0.35);
    x = GMath.lerp(-80, 40, t);
    return;
  }

  if (time < 1.2) {
    x = 40;
    alpha = 1;
    return;
  }

  if (time < 1.5) {
    final t = GMath.clamp((time - 1.2) / 0.3);
    alpha = GMath.lerp(1, 0, t);
    return;
  }

  alpha = 0;
  updatesEnabled = false;
}
```

This is intentionally plain code.

For a one-off toast or intro beat, plain code can be easier to debug than introducing a timeline abstraction too early.

If the same structure starts appearing everywhere, **that repetition is evidence for a reusable motion package/API**, not a reason to predict one prematurely in the core manual.

## Follow a moving target with smoothing

A common visual trick is to move partway toward the target every frame:

```dart
final responsiveness = 10.0;
final t = 1.0 - GMath.exp(-responsiveness * delta);

x = GMath.lerp(x, targetX, t);
y = GMath.lerp(y, targetY, t);
```

This is exponential smoothing.

Unlike this frame-dependent version:

```dart
x += (targetX - x) * 0.1;
```

using `delta` makes the response much more consistent across refresh rates.

It does **not** overshoot like a spring. It simply approaches the moving target smoothly.

So you now have two different feels:

```text
exponential smoothing → soft approach, no overshoot
spring + damping      → inertia, overshoot, settling
```

Choose by motion character, not by which equation looks fancier.

## Stop asking for frames when the animation ends

A one-shot animation should eventually do:

```dart
updatesEnabled = false;
```

That is more than tidiness. It returns GraphX to its demand-driven update model.

A scene made from many little one-shot animations can become idle again once they finish instead of carrying a permanent frame loop forever.

## Animation can stay small

There is no requirement that every changing property be managed by a grand animation architecture.

Sometimes the clearest expression really is:

```dart
rotation += delta;
```

Sometimes it is a `lerp`.

Sometimes it is a spring.

Sometimes several coordinated effects deserve a reusable motion abstraction.

The useful skill is recognizing the motion you want before choosing the machinery that drives it.
