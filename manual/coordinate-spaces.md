# Coordinate spaces

Coordinate spaces become important the moment a scene has more than one transform hierarchy.

A common editor setup is a pannable/zoomable `world` containing scene objects, plus a root-level HUD containing tooltips, guides, or selection UI. A point that is simple inside the world may need to be displayed or manipulated in the overlay.

That is where coordinate conversion stops being matrix theory and becomes ordinary scene plumbing.

## Every parent creates a little world

In [Nodes and children](#nodes-and-children), we saw that a child's position is relative to its parent.

```dart
final world = root.addChild(GNode());
final hud = root.addChild(GNode());
final object = world.addChild(GShape());

world.setPosition(200, 100);
world.scale = 1.5;
object.setPosition(40, 30);
```

For `object`, `(40, 30)` is perfectly meaningful: it is the object's position inside the transformed world.

The root sees the same point somewhere else because the world itself has been translated and scaled.

Both answers can be correct. They are simply describing the point in different coordinate spaces.

## Local to global

Suppose we want to know where the object's own origin ends up in the GraphX stage:

```dart
final point = object.localToGlobal(0, 0);

print(point.x);
print(point.y);
```

`localToGlobal()` starts with a point in the node's local space and follows the parent transforms all the way up.

The names may already look familiar if you have worked with Flutter render objects: `RenderBox` also has `localToGlobal()` and `globalToLocal()`.

There is one important difference in what "global" means here. In GraphX, "global" is the stage/world coordinate space of the scene. It is not Flutter's screen-global coordinate system.

That distinction matters when GraphX is itself positioned somewhere inside a Flutter layout.

## Global back to local

The conversion works in the other direction too.

A common source of stage coordinates is the GraphX pointer manager. Its `x` and `y` values describe the current pointer position in the stage's coordinate space:

```dart
final pointer = root.stage.pointer;

final local = object.globalToLocal(
  pointer.x,
  pointer.y,
);

if (local != null) {
  print(local.x);
  print(local.y);
}
```

Now the pointer position, which started in stage coordinates, is translated into `object`'s local space.

That lets you ask questions such as: **where is the pointer relative to this object?** A point at `(0, 0)` would be exactly on its local origin; `(20, 10)` would be 20 across and 10 down in that object's own coordinate system.

The result can be `null` when the transform cannot be inverted — for example, if a scale collapses an axis completely.

Most ordinary transforms are invertible, so this is usually something you simply keep in mind rather than design around.

## From one node to another

Going through global coordinates yourself would work, but GraphX can translate directly between two nodes on the same stage:

```dart
final pointInHud = object.localToNode(
  hud,
  180,
  48,
);
```

Read that as:

> Where is this local anchor on `object` when described in `hud` coordinates?

Now a root-level tooltip, connector preview, or alignment guide can follow something inside a deeply transformed world without duplicating the camera/world transform math in application code.

## Points and movement are slightly different

A point has a position. A movement does not.

If you are translating a direction or delta — perhaps a drag amount — use the delta form:

```dart
final dragInWorld = hud.localDeltaToNode(
  world,
  deltaX,
  deltaY,
);
```

Translation is ignored for a delta, while scale and rotation still matter.

That is a small distinction, but it prevents a surprisingly common class of coordinate bugs.

## The `Into` forms

The convenient conversion methods return a `GPoint`:

```dart
final point = node.localToGlobal(10, 20);
```

When a conversion happens very often — for example inside animation, hit testing, or a large simulation — GraphX also provides forms that write into an existing point:

```dart
final point = GPoint();

node.localToGlobalInto(10, 20, point);
```

The result is the same without allocating a new `GPoint` each time.

Use the convenient version first. Reach for the `Into` version when the code is hot enough for the difference to matter.

## Why `GPoint` instead of Flutter's `Offset`?

Flutter already has `Offset`, so it is reasonable to wonder why GraphX has another two-number point type.

The important difference is that `Offset` is an immutable value. `GPoint` is a small mutable geometry object owned by GraphX.

That lets hot APIs reuse one point instead of creating a new object every time:

```dart
final point = GPoint();

for (final node in nodes) {
  node.localToGlobalInto(0, 0, point);
  // use point, then reuse it for the next node
}
```

For ordinary code, the allocating convenience methods are usually nicer. The mutable form matters when transforms, input, animation, or geometry run thousands of times per frame.

GraphX does not make you choose between its geometry and Flutter's. The public bridge works in both directions:

```dart
final Offset flutterPoint = point.offset;
final GPoint graphxPoint = flutterPoint.gpoint;
```

And when you want to reuse an existing `GPoint`:

```dart
flutterPoint.copyInto(point);
```

The same idea exists for `GSize`/`Size`, `GRect`/`Rect`, and `GBounds`/`Rect`.

So `GPoint` is not there because Flutter's `Offset` is inadequate. It exists because a retained graphics engine benefits from mutable, allocation-aware scratch geometry while still interoperating cleanly with Flutter values.

## Ask two questions

You do not need to mentally multiply matrices every time two objects need to talk.

Ask two questions instead:

1. **What space is this point in now?**
2. **What space do I need it in?**

Then choose the conversion that says exactly that.

Once that habit clicks, nested transforms become much less mysterious.
