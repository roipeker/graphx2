# Fixed-step simulation

Variable `delta` is excellent for ordinary visual motion.

Physics and deterministic simulation sometimes want a stricter rule:

> advance the simulation in identical-sized steps, no matter how irregular the host frames are.

That is fixed stepping.

## Why variable steps can change a simulation

Consider gravity:

```dart
velocityY += gravity * delta;
y += velocityY * delta;
```

A sequence of ten `0.01` steps does not produce exactly the same numerical result as one `0.10` step.

Both approximate the same continuous system, but the approximation error differs.

Collisions make this even more obvious. One giant step may leap completely over a thin wall that several smaller steps would detect.

## Accumulate time, simulate in fixed chunks

A common pattern is:

```dart
const fixedStep = 1 / 60;

double accumulator = 0;

@override
void update(double delta) {
  accumulator += delta;

  while (accumulator >= fixedStep) {
    simulate(fixedStep);
    accumulator -= fixedStep;
  }
}
```

Now `simulate()` always sees the same timestep:

```dart
void simulate(double delta) {
  velocityY += gravity * delta;
  y += velocityY * delta;
}
```

A 120 Hz display may run one fixed simulation step every other host frame.

A slower frame may run several simulation steps before rendering once.

The simulation cadence and render cadence are no longer the same thing.

## Put a ceiling on catch-up work

If the application stalls for a long time, trying to replay thousands of physics steps can create the famous **spiral of death**: catching up takes so long that the next frame is even later.

Cap the number of steps per frame:

```dart
const fixedStep = 1 / 60;
const maxSteps = 5;

double accumulator = 0;

@override
void update(double delta) {
  accumulator += delta;

  var steps = 0;
  while (accumulator >= fixedStep && steps < maxSteps) {
    simulate(fixedStep);
    accumulator -= fixedStep;
    steps++;
  }

  if (steps == maxSteps) {
    accumulator = GMath.min(accumulator, fixedStep);
  }
}
```

That chooses responsiveness over attempting infinite catch-up.

The exact policy belongs to the application/simulation. A networked deterministic game may make a different choice from a decorative physics effect.

## GraphX `maxDelta` still happens first

GraphX already clamps the `delta` delivered to update code using `GraphXConfig.maxDelta`.

So your accumulator receives **GraphX simulation time**, not the raw wall-clock gap from the host.

With the default `maxDelta` of `1 / 15`, a 60 Hz fixed simulation can receive at most about four fixed steps worth of time from a single GraphX update.

That is a useful safety guard, but it means a two-second debugger pause does not become two seconds of hidden catch-up work. The excess host time has already been discarded by the stage clamp.

Fixed stepping solves **variable integration step size**. It does not undo GraphX's deliberate late-frame clamp.

## Render between simulation states

After fixed stepping, the accumulator usually contains a fraction of the next step:

```dart
final alpha = accumulator / fixedStep;
```

That value is in the familiar `0..1` range.

A more advanced simulation can keep the previous/current simulation states and interpolate a render position between them:

```dart
renderX = GMath.lerp(previousX, currentX, alpha);
renderY = GMath.lerp(previousY, currentY, alpha);
```

This lets physics advance at a stable fixed cadence while rendering remains smooth at the display cadence.

Do not add that machinery unless the visual result needs it. Plenty of simulations are perfectly acceptable rendering the latest fixed state directly.

## Determinism needs more than a fixed timestep

A fixed timestep is necessary for many deterministic systems, but not sufficient by itself.

Determinism can also depend on:

```text
input ordering
random-number generation
floating-point behavior
iteration order
collision ordering
external state
```

So treat fixed stepping as the foundation of deterministic simulation, not a magic switch that guarantees identical outcomes everywhere.

## Ordinary motion should stay ordinary

If you are moving a menu icon from left to right, this:

```dart
x += speed * delta;
```

is likely all you need.

Fixed stepping earns its complexity when the simulation itself benefits from a stable numerical timestep—physics, collisions, lockstep logic, or systems where reproducibility matters.
