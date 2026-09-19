# Springs and damping

Interpolation moves a value along a planned path.

A spring behaves differently: it reacts to where the target **is now**.

Drag a card. Let go. Move the target again before it settles. The spring changes course naturally because there is no prewritten timeline to finish.

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

That tiny system is enough for a surprising amount of interactive motion:

```text
pointer-following blobs
camera follow
elastic menus
floating labels
soft drag handles
springy HUD elements
```

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

So this works naturally:

```dart
node.pointer.onMove.add((event) {
  targetX = event.stageX;
  targetY = event.stageY;
});
```

The spring never needs to cancel and restart a timeline when the pointer changes direction.

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
