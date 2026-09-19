# Lifecycle and the stage

A `GNode` can exist before GraphX knows anything about a viewport, pointer, runtime, or asset store.

That is why stage-dependent work has a lifecycle boundary.

## Constructors build the object; `attached()` joins the scene runtime

This is fine in a constructor:

```dart
class Player extends GNode {
  Player() {
    name = 'player';
  }
}
```

But a detached node does not have a usable stage. The public `stage` getter is deliberately **non-nullable**:

```dart
GStage get stage
```

Access it while the node is detached and GraphX throws instead of handing you `null` and making every caller carry `stage?` checks forever.

The guaranteed place for stage-dependent setup is `attached()`:

```dart
class Player extends GNode {
  @override
  void attached() {
    print(stage.width);
    print(stage.height);

    final pointer = stage.pointer;
    final assets = stage.assets;
  }
}
```

By the time `attached()` runs, the node has crossed the GraphX stage lifecycle boundary. `stage` is valid, and a `GraphXView`-hosted root has a usable viewport.

If code can run both attached and detached, ask the lifecycle directly:

```dart
if (player.isAttached) {
  print(player.stage.width);
}
```

The API is saying something intentional here: **stage access is a lifecycle fact, not an optional value.**

If you remember the original GraphX or the Flash display list, `attached()` / `detached()` occupy the territory that used to be described as added-to-stage / removed-from-stage. GraphX² makes one deliberate change to that old mental model: instead of carrying a nullable stage reference through normal code, detached access is invalid and attachment gives you a non-nullable `stage`.

## The callback scene starts at that same boundary

`GraphXView.scene(...)` does not call its builder while the root is a half-constructed detached object. The callback is run from the callback root's `attached()` hook.

That is why this is valid immediately:

```dart
GraphXView.scene((root) {
  print(root.stage.width);
  print(root.stage.height);

  final assets = root.stage.assets;
});
```

Callback mode and class mode therefore enter the same runtime at the same lifecycle boundary. One expresses setup in a closure; the other overrides a method.

## `detached()` still has the stage for cleanup

When a node leaves the stage, GraphX calls `detached()` before clearing its stage ownership.

That means cleanup can still refer to the stage it is leaving:

```dart
class Overlay extends GNode {
  GSignalSubscription? _resizeSubscription;

  @override
  void attached() {
    _resizeSubscription = stage.signals.onResize.add(_handleResize);
  }

  void _handleResize(GSize size) {
    // Reposition retained overlay content.
  }

  @override
  void detached() {
    _resizeSubscription?.cancel();
    _resizeSubscription = null;

    print('leaving ${stage.width} × ${stage.height}');
  }
}
```

This matters because detachment is not necessarily destruction. A node can leave one stage tree and later be attached again.

`dispose()` is different: disposal is terminal.

## Reparenting inside one stage is not a lifecycle event

Suppose a card moves from one group to another while both groups already belong to the same stage:

```dart
frontLayer.addChild(card);
```

GraphX reparents it without manufacturing a `detached()` / `attached()` pair. The node never left the stage runtime; only its parent changed.

That keeps lifecycle hooks about the thing they actually describe: entering or leaving a stage, not ordinary scene-tree rearrangement.

The lifecycle sequence is:

```text
construct
   ↓
add to attached stage
   ↓
attached()
   ↓
reparent inside same stage  ← no lifecycle break
   ↓
remove from stage
   ↓
detached()
   ↓
attach again, or dispose permanently
```

## The stage is the runtime boundary

Once attached, `stage` is where scene-wide runtime state lives.

A few examples are direct core stage capabilities:

```dart
stage.width
stage.height
stage.devicePixelRatio
stage.delta
stage.frame

stage.pointer
stage.input
stage.assets
stage.runtime
stage.environment
stage.signals
```

A node owns local scene behavior. The stage owns context shared by the scene: viewport, timing, input, runtime resources, environment, and stage-wide signals.

That is why loading an asset, observing a viewport resize, or reading pointer state naturally waits until attachment.

## Some stage capabilities arrive through Dart extensions

GraphX keeps the base `GStage` relatively small. Optional or more specialized systems can present a stage-scoped API through Dart extensions instead of forcing every subsystem into the core class.

For example:

```dart
final focus = stage.focus;
final actions = stage.actions;
final views = stage.renderViews;

final topNode = stage.hitTest(120, 80);
```

To user code these read naturally as stage capabilities. Internally they do not all live as permanent fields on `GStage`.

`stage.focus`, for example, lazily creates stage-local focus state when first requested. `stage.renderViews` similarly creates the explicit render-view collection only when a scene opts into it. Stateless helpers such as `stage.hitTest()` can be added as extension APIs without adding storage at all.

There is no generic public `stage.extensions` service locator to learn. The pattern is simpler: **the stage is the owner/key for scene-wide behavior, while Dart extensions let GraphX and extension packages add focused APIs without bloating the core stage object.**

This is also why an extension package can feel native to the engine. It can add a stage-facing capability while keeping its own implementation and lazy state outside the base scene classes.

## Nodes have signals when inheritance is not the right shape

Overrides are natural inside your own node class:

```dart
@override
void attached() {
  // node-owned setup
}
```

Code outside that class can observe the same boundary through node signals:

```dart
node.signals.onAttached.add(() {
  // external behavior noticed the attachment
});

node.signals.onDetached.add(() {
  // external behavior noticed the detachment
});
```

There is also `onDispose` for the final teardown boundary.

That mirrors the pattern we saw with callback roots: GraphX exposes lifecycle as overridable methods when behavior belongs to a type, and as signals when behavior is being composed from the outside.

## `GRoot` adds host-facing lifecycle on top

`GRoot` is still a node, so it gets the same `attached()` / `detached()` lifecycle.

It additionally owns the scene-level hooks that come from the Flutter host:

```dart
class Scene extends GRoot {
  @override
  void resize(double width, double height) {
    // The GraphX viewport changed.
  }

  @override
  void environmentChanged(GEnvironmentChange change) {
    // A consumed host environment value changed.
  }

  @override
  void reassemble() {
    // Retained development hot-reload hook.
  }
}
```

`resize()` runs after the initial attachment with the first usable viewport and again when that viewport changes.

A plain child node does not need its own special resize lifecycle. If it cares about viewport size, it can subscribe to `stage.signals.onResize` while attached, as the overlay example did earlier.

The hierarchy stays small: **nodes own node lifecycle; the root adds scene/host lifecycle; the stage carries the shared runtime.**
