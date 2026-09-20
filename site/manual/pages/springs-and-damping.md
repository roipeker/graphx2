# Springs and damping

Interpolation moves a value along a planned path.

A spring behaves differently: it reacts to where the target **is now**.

That makes springs especially useful for things such as a camera following a moving subject. The target can accelerate, reverse, or teleport to a new point; the spring simply reacts to the new error instead of cancelling and rebuilding a timeline.

## Start with the distance to the target

```dart
final distance = targetX - x;
```

If the target is to the right, distance is positive.

If the target is to the left, distance is negative.

Turn that distance into acceleration:

```dart
final acceleration = distance * stiffness;
```

The farther away we are, the harder the spring pulls back.

## Acceleration changes velocity; velocity changes position

```dart
double velocityX = 0;
final stiffness = 80.0;

@override
void update(double delta) {
  final distance = targetX - x;
  final acceleration = distance * stiffness;

  velocityX += acceleration * delta;
  x += velocityX * delta;
}
```

That moves toward the target—but it will happily overshoot forever.

A perfect undamped spring keeps exchanging potential and kinetic energy.

For UI/motion work, we usually want it to settle.

## Damping removes energy

A simple exponential damping factor is:

```dart
final dampingFactor = GMath.exp(-damping * delta);
```

Apply it to velocity:

```dart
double velocityX = 0;
final stiffness = 80.0;
final damping = 10.0;

@override
void update(double delta) {
  final distance = targetX - x;
  final acceleration = distance * stiffness;

  velocityX += acceleration * delta;
  velocityX *= GMath.exp(-damping * delta);
  x += velocityX * delta;
}
```

Now the motion can overshoot, reverse, and gradually settle.

`stiffness` controls how aggressively the spring pulls.

`damping` controls how quickly motion loses energy.

The numbers are intentionally exposed as feel parameters here rather than pretending we are modelling a calibrated physical spring in SI units.

## Why exponential damping?

This tempting version:

```dart
velocityX *= 0.9;
```

means “lose 10% **per frame**.”

At 120 fps that damping happens twice as often as at 60 fps, so the feel changes with frame rate.

This version:

```dart
velocityX *= GMath.exp(-damping * delta);
```

expresses damping over elapsed time instead.

That does not make the entire spring numerically perfect for arbitrary huge timesteps—the integration still matters—but it removes one common frame-rate dependency.

## Two dimensions are the same spring twice

```dart
double velocityX = 0;
double velocityY = 0;

@override
void update(double delta) {
  final ax = (targetX - x) * stiffness;
  final ay = (targetY - y) * stiffness;
  final drag = GMath.exp(-damping * delta);

  velocityX += ax * delta;
  velocityY += ay * delta;

  velocityX *= drag;
  velocityY *= drag;

  x += velocityX * delta;
  y += velocityY * delta;
}
```

The same two-axis system can drive a camera rig, selection affordance, draggable inspector, or any retained object that should respond continuously to a moving target rather than follow a predetermined timeline.

## A spring can chase a moving target

That is where it differs most from a conventional interpolation.

With interpolation you normally capture:

```text
start → end → duration
```

With a spring you keep asking:

```text
where is the target now?
how far away am I?
```

For a camera, the target can simply track the subject's current position:

```dart
targetX = player.x;
targetY = player.y;
```

If the player changes direction during the settle, the camera's acceleration changes on the next update. Nothing needs to cancel or restart because the spring is defined by the current distance to the target, not by an old endpoint captured at animation start.

## Stop updating once the spring is asleep

A spring that is visually settled does not need to tick forever.

```dart
final distance = GMath.abs(targetX - x);
final speed = GMath.abs(velocityX);

if (distance < 0.01 && speed < 0.01) {
  x = targetX;
  velocityX = 0;
  updatesEnabled = false;
}
```

When the target moves again:

```dart
updatesEnabled = true;
```

That fits GraphX's demand-driven update model nicely: dynamic while motion exists, idle when nothing is happening.

## Springs make math visible

The equations are small, but the result has personality.

Change `stiffness` and the object feels heavier or more eager. Change damping and it becomes bouncy or restrained.

That feedback loop—change a number, immediately *feel* the result—is one of the nicest ways to learn motion math.

> **Go deeper:** [Nature of Code — Oscillation](https://natureofcode.com/oscillation/) carries this into angular motion, waves, pendulums, and spring forces with runnable visual examples.
