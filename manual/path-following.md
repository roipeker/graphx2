# Following a path

A Bézier curve is nice to draw.

It gets even more interesting when something can travel along it.

Flutter's native `Path` already knows how to measure and sample its contours, so GraphX does not need to invent a second path-motion format.

## Keep one path as the source of truth

Build a normal Dart path:

```dart
final path = Path();
path.moveTo(40, 220);
path.cubicTo(
  100, 20,
  260, 20,
  340, 220,
);
```

Draw that exact path into GraphX:

```dart
final track = root.addChild(GShape());
track.graphics
    .lineStyle(3, Colors.blueGrey)
    .drawPath(path)
    .endStroke();
```

Now the visible track and the motion sampler can refer to the same geometry.

`GGraphics.drawPath()` copies the path into retained graphics. If you later mutate the original Dart `Path`, redraw/update the GraphX geometry too so the two do not silently drift apart.

## `PathMetric` measures actual contour length

```dart
final metrics = path.computeMetrics().toList(growable: false);
final metric = metrics.first;
```

For a simple one-contour path:

```dart
print(metric.length);
```

returns its measured length in local path units.

`PathMetric` describes the path as it existed when `computeMetrics()` was called. If you later mutate the source `Path`, recompute its metrics before using them for motion.

This is already different from Bézier parameter `t`.

A cubic curve at:

```text
t = 0.5
```

is halfway through the mathematical parameter, but not necessarily halfway along the physical distance of the curve.

A `PathMetric` offset **is distance along the contour**.

That is exactly what constant-speed motion wants.

## Sample a point by distance

```dart
final tangent = metric.getTangentForOffset(distance);
if (tangent == null) return;

follower.setPosition(
  tangent.position.dx,
  tangent.position.dy,
);
```

The returned tangent gives both:

```text
position on the path
local direction of the path
```

So one query can place and orient the follower.

## Rotate with the path direction

Use the tangent vector itself:

```dart
final vector = tangent.vector;
final angle = GMath.atan2(vector.dy, vector.dx);

follower.rotation = angle;
```

Now an arrow/ship/marker turns naturally as the curve bends.

Using the vector directly avoids relying on any backend-specific angle convention from `PathMetric`; the direction is explicit in `(dx, dy)`.

## Move at units per second

Store path distance as motion state:

```dart
double distance = 0;
final speed = 120.0;
```

Then:

```dart
@override
void update(double delta) {
  distance += speed * delta;

  final tangent = metric.getTangentForOffset(distance);
  if (tangent == null) {
    updatesEnabled = false;
    return;
  }

  follower.setPosition(
    tangent.position.dx,
    tangent.position.dy,
  );

  final vector = tangent.vector;
  follower.rotation = GMath.atan2(
    vector.dy,
    vector.dx,
  );
}
```

The speed is now expressed in **path units per second**.

Curvy sections do not automatically move faster just because the Bézier parameter happens to stretch there.

## Loop a closed route

For a closed contour:

```dart
final d = GMath.wrap(distance, metric.length);
final tangent = metric.getTangentForOffset(d);
```

The follower loops forever without resetting its motion state.

For an open contour where you still want looping, wrapping is a stylistic choice; the object will jump from the end back to the beginning because the geometry itself is not closed.

## Keep the path and follower in the same local space

The easiest setup is:

```text
routeGroup
├── pathShape
└── follower
```

Both are positioned in `routeGroup` local coordinates.

Then the `PathMetric` sample can go straight into:

```dart
follower.setPosition(x, y);
```

Move/scale/rotate the whole route group later and both the drawn path and follower transform together.

If the follower lives somewhere else in the hierarchy, convert between spaces explicitly rather than mixing coordinates by accident.

## A path may contain several contours

`computeMetrics()` returns one metric per contour.

A path built with several disconnected `moveTo()` sections is therefore not one continuous route automatically:

```dart
for (final metric in path.computeMetrics()) {
  print(metric.length);
}
```

For authored motion, decide whether those contours are:

```text
separate routes
sequential route segments
or geometry that should have been one connected contour
```

The API does not guess that semantic choice for you.

## Tangents unlock more than rotation

Once you have the tangent direction, you can derive a perpendicular normal:

```dart
final dx = tangent.vector.dx;
final dy = tangent.vector.dy;
final length = GMath.hypo(dx, dy);

if (length > GMath.epsilon) {
  final nx = -dy / length;
  final ny = dx / length;
}
```

That normal can offset something beside the route:

```dart
label.setPosition(
  tangent.position.dx + nx * 18,
  tangent.position.dy + ny * 18,
);
```

Now labels, particles, rails, road shoulders, and camera offsets can sit consistently to one side of the curve.

The same small vector ideas keep reappearing because they really are the same geometry.

## Sampling is different from drawing

`GGraphics` retains the path for rendering.

`PathMetric` gives you measurements/samples for logic.

Those are complementary responsibilities:

```text
Dart Path
   ├── drawPath()        → retained GraphX visual
   └── computeMetrics()  → length / position / tangent
```

That is a nice boundary: GraphX does not need to hide Flutter's already-good path mathematics behind another wrapper just to make motion possible.
