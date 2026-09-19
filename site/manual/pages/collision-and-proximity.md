# Collision and proximity

Two objects overlap. Now what?

GraphX core gives you geometry, coordinate conversion, bounds, and timing. It does **not** pretend that automatically makes it a full rigid-body physics engine.

That is a good boundary to understand.

## Start with both objects in the same coordinate space

Collision math only makes sense when the values being compared describe the same world.

For two nodes somewhere under the same root:

```dart
final aBounds = player.getBounds(root);
final bBounds = wall.getBounds(root);
```

Those two `GBounds` now describe both subtrees in `root` space.

Then the broad question is easy:

```dart
if (aBounds.intersects(bBounds)) {
  print('possible collision');
}
```

## Bounds are a broad-phase test

`getBounds(root)` returns an axis-aligned enclosing box in that target space.

If a thin rotated rectangle looks like this:

```text
   /------/
  /------/
```

its axis-aligned bounds look more like:

```text
+----------+
|  /----/  |
| /----/   |
+----------+
```

Two such boxes can overlap even when the actual artwork does not.

That is why bounds intersection is usually called **broad phase**:

> these objects are close enough that an exact collision *might* be worth checking.

It is excellent for cheaply rejecting obvious non-collisions.

It is not magically exact for every shape.

## Circle vs circle is almost embarrassingly small

For circular objects:

```dart
final dx = b.x - a.x;
final dy = b.y - a.y;
final radius = radiusA + radiusB;

final collided = dx * dx + dy * dy <= radius * radius;
```

No square root is required.

If the squared center distance is less than the squared combined radius, the circles overlap.

That one test is enough for a surprising number of games and visual interactions.

## Proximity is often more useful than collision

Sometimes the question is not “did they touch?”

It is:

> is the pointer/enemy/object close enough that I should react?

```dart
final dx = targetX - x;
final dy = targetY - y;
final near = dx * dx + dy * dy < 120 * 120;
```

That can drive:

```text
magnetic snapping
hover attraction
AI awareness
sound falloff zones
particle activation
editor guides
```

Many interactions feel better when they begin *before* exact contact.

## Point inside a transformed node

If you have a point in stage/root space and want to test local geometry, convert first:

```dart
final local = node.globalToLocal(stageX, stageY);
if (local == null) return;

final inside = node.selfBounds.contains(local.x, local.y);
```

That handles the node hierarchy/affine transforms before the local test.

`selfBounds` means the node's own intrinsic local geometry. `localBounds` includes descendants too, which may be exactly what you want for a composite object—but it should be a deliberate choice.

Both are still axis-aligned boxes. For an exact custom shape test, use geometry appropriate to the shape rather than treating its bounds as the shape itself.

The pointer system already has richer hit-area/path logic; collision code should not accidentally assume “pointer hit test” and “physics collision” are always the same concept.

## Hidden geometry still has geometry

As covered in [Bounds](#bounds), canonical bounds describe the retained scene geometry, not whether the node currently happens to paint.

So collision logic should make its own participation rule explicit:

```dart
if (!enemy.visible || !enemy.active) return;
```

if that is what your game/simulation means.

Do not expect `getBounds()` to silently redefine the world because something is hidden.

## Masks, glows, and shadows are usually not collision shapes

A glow may extend twenty pixels outside a button.

A mask may hide half an image.

Neither necessarily means the physical/logical collision shape should change.

GraphX deliberately separates:

```text
canonical geometry
interaction hit geometry
rendered effect pixels
```

Collision can be a fourth semantic choice if the application needs one.

That separation prevents every visual effect from rewriting gameplay/editor geometry behind your back.

## Collision response is another problem

Detecting overlap is only step one.

After collision you may want to:

```text
stop movement
push objects apart
bounce velocity
slide along a surface
trigger a sensor
apply damage
play a sound
```

Those behaviors require more information than a yes/no overlap test: contact normal, penetration depth, previous position, velocity, material rules, continuous collision detection, etc.

That is physics/collision-system territory.

GraphX core should not fake that depth with a convenience `collidesWith()` method that only compares bounding boxes.

## A practical layered strategy

For many custom systems, the structure is:

```text
1. cheap broad phase
   bounds / spatial chunk / distance

2. narrow phase only for candidates
   circle / path / polygon / custom geometry

3. application-specific response
   bounce / stop / trigger / slide / etc.
```

That pattern scales from a tiny game to much more serious spatial systems.

The important first habit is the same one we used for coordinates: **know what space and what geometry you are comparing.**
