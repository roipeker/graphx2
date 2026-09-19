# Frame updates

A static scene should not burn CPU just because it exists.

GraphX only keeps asking Flutter for animation frames while something in the stage actually needs continuous updates.

## A node opts into the frame loop

`GNode` has an update hook, but it is dormant by default:

```dart
class Spinner extends GNode {
  Spinner() {
    updatesEnabled = true;
  }

  @override
  void update(double delta) {
    rotation += delta;
  }
}
```

Once the node belongs to an attached stage, enabling updates registers it with that stage's updater list.

Disable it again when the object no longer needs time:

```dart
spinner.updatesEnabled = false;
```

If no node updater or stage update signal remains active, GraphX can stop its continuous tick scheduling.

The picture can stay on screen without an animation loop running underneath it.

## `active` also controls that node's updater

An active updater participates in the stage loop:

```dart
spinner.active = true;
```

Deactivate the node:

```dart
spinner.active = false;
```

and GraphX removes **that node** from update execution until it becomes active again.

That ties back to [Visibility and activity](#visibility-and-activity): `visible` is about rendering/interaction; `active` reaches into runtime participation too.

One nuance matters in a large hierarchy: child nodes register their own updates independently. Deactivating a parent does not magically rewrite each descendant's `active` flag or unregister separately-updating descendants. If an entire simulation branch needs to pause, model that pause deliberately for the branch rather than assuming parent activity is a recursive global switch.

## Callback scenes can listen instead of overriding

For a small callback scene:

```dart
GraphXView.scene((root) {
  final dot = root.addChild(GShape());

  root.onUpdate.add((delta) {
    dot.rotation += delta;
  });
});
```

`GRoot.onUpdate` is a shortcut to the stage's primary update signal.

Adding a listener keeps the stage ticking continuously for as long as that listener remains active.

That makes callback mode genuinely useful for small motion experiments: there is no class to create just to rotate one object.

## Node updates run before stage update signals

The frame order is intentional:

```text
node update(delta)
      ↓
stage.onUpdate
      ↓
stage.onPostUpdate
      ↓
stage.onLateUpdate
      ↓
input frame state is cleared
```

Most scenes only need the first two levels.

`onPostUpdate` and `onLateUpdate` exist for systems that need a stable phase after ordinary updates—for example a camera that follows objects after they moved, or a package that needs final per-frame reconciliation.

You do not need to divide ordinary game/app code across every phase just because they exist.

## Why there is more than one phase

Imagine a player moves in its node update and a camera wants to follow the player's **new** position.

If both pieces run in one unordered pile, somebody has to win by accident.

A later phase gives the dependency a name:

```dart
stage.signals.onLateUpdate.add((delta) {
  cameraX = player.x;
});
```

That is often cleaner than inventing fragile registration order dependencies.

## One-shot updates are different from continuous animation

`stage.requestUpdate()` asks the host for update work without permanently installing a continuous updater.

Input uses that mechanism internally so fresh pointer state can be observed by the next GraphX frame even when the scene was otherwise idle.

It is not the normal way to animate an object. For continuous motion, enable a node updater or add a stage update listener so the stage clearly knows that time is still required.

## The stage counts time and frames for you

While ticking:

```dart
print(stage.delta);
print(stage.elapsed);
print(stage.frame);
```

`delta` is the current update timestep in seconds.

`elapsed` accumulates GraphX's **clamped simulation/update time**, not an authoritative wall clock.

`frame` increments once per stage tick.

The next chapter uses that `delta` to make motion independent of whether the host is currently delivering 30, 60, or 120 frames per second.
