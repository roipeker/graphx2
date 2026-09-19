# Delta time and motion

Let us move something without making its speed secretly depend on the monitor refresh rate.

The whole idea starts with one equation:

```text
distance = velocity × time
```

## `delta` is seconds since the previous GraphX update

A node update receives:

```dart
void update(double delta)
```

At roughly 60 fps, `delta` is often near:

```text
0.0167 seconds
```

At roughly 30 fps it may be closer to:

```text
0.0333 seconds
```

Those values are not targets. They are measurements of the update timestep GraphX is giving your simulation after applying `maxDelta` protection.

## Move at pixels per second, not pixels per frame

Suppose a ball should move 180 scene units per second:

```dart
class Ball extends GNode {
  Ball() {
    updatesEnabled = true;
  }

  double velocityX = 180;

  @override
  void update(double delta) {
    x += velocityX * delta;
  }
}
```

At 60 fps:

```text
180 × 0.0167 ≈ 3 units this frame
```

At 30 fps:

```text
180 × 0.0333 ≈ 6 units this frame
```

Fewer updates, larger steps. Over the same real span of time, the ball travels roughly the same distance.

That is the first piece of frame-rate-independent motion.

## Two dimensions are just two velocities

```dart
double velocityX = 140;
double velocityY = -60;

@override
void update(double delta) {
  x += velocityX * delta;
  y += velocityY * delta;
}
```

Now velocity is a 2D direction and speed rolled into two numbers.

Later we can introduce proper vector helpers and ask questions such as “how fast?” or “which direction?” without manually carrying two scalars everywhere. The math is the same.

## Speed plus angle is another way to describe velocity

Sometimes you know the direction as an angle:

```dart
final speed = 180.0;
final angle = GMath.radians(30);

final velocityX = GMath.cos(angle) * speed;
final velocityY = GMath.sin(angle) * speed;
```

Then the same update equation applies:

```dart
x += velocityX * delta;
y += velocityY * delta;
```

This is where trigonometry stops being a school diagram and becomes “send this object 30 degrees across the screen.”

[Angles, sine, and cosine](#angles-sine-and-cosine) gives that direction math its own visual treatment.

## Acceleration changes velocity

Gravity is not a position change. It is a velocity change over time.

```dart
double velocityY = 0;
final gravity = 900.0;

@override
void update(double delta) {
  velocityY += gravity * delta;
  y += velocityY * delta;
}
```

Read it in two steps:

```text
velocity changes because of acceleration
position changes because of velocity
```

That tiny pair of equations is the beginning of numerical integration.

It is also why timestep size matters: each update approximates continuous motion with discrete steps.

## This is Euler integration

The gravity example uses a common form of semi-implicit Euler integration: update velocity from acceleration, then update position from the new velocity.

You do not need the name to use it, but names become helpful once we compare integration methods or build springs/physics.

For many visual effects and simple games, this is already enough.

## `maxDelta` protects against absurd single steps

If a debugger pauses for two seconds, blindly applying:

```text
velocity × 2 seconds
```

could teleport an object across the scene and skip every collision in between.

GraphX clamps the delivered `delta` using `GraphXConfig.maxDelta` to put a ceiling on that single update.

As covered earlier, clamping is a guardrail—not a fixed-step physics engine. Time beyond the clamp is not replayed automatically.

## Fixed-step simulation is the next level, not the first requirement

A deterministic physics simulation often wants something more structured:

```text
accumulate real frame time
        ↓
run 0..N fixed simulation steps
        ↓
optionally interpolate for rendering
```

That solves a different problem from basic visual motion.

For now, the rule is enough:

**express rates per second, then multiply by `delta`.**

That one habit makes a surprising amount of animation code behave sensibly across devices.
