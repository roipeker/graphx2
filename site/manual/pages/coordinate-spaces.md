# Coordinate spaces

Sooner or later, one object needs to know where another object is.

A button wants to point at a character. A particle should start at the tip of a moving wand. A drag that began inside one container needs to make sense inside another.

That is when coordinate spaces stop sounding abstract and become useful.

## Every parent creates a little world

In [Nodes and children](#nodes-and-children), we saw that a child's position is relative to its parent.

```dart
final panel = root.addChild(GNode());
final button = panel.addChild(GShape());

panel.setPosition(200, 100);
button.setPosition(40, 30);
```

For `button`, `(40, 30)` is perfectly meaningful. It means 40 across and 30 down inside `panel`.

But the root sees that same point somewhere else because `panel` itself has moved.

Both answers can be correct. They are simply describing the point in different coordinate spaces.

## Local to global

Suppose we want to know where the button's own origin ends up in the GraphX stage:

```dart
final point = button.localToGlobal(0, 0);

print(point.x);
print(point.y);
```

`localToGlobal()` starts with a point in the node's local space and follows the parent transforms all the way up.

In GraphX, "global" here means the stage/world coordinate space of the scene. It is not Flutter's screen-global coordinate system.

That distinction matters when GraphX is itself positioned somewhere inside a Flutter layout.

## Global back to local

The opposite conversion is just as useful:

```dart
final local = button.globalToLocal(stageX, stageY);

if (local != null) {
  print(local.x);
  print(local.y);
}
```

Now a point expressed in stage coordinates is translated back into `button`'s local space.

The result can be `null` when the transform cannot be inverted — for example, if a scale collapses an axis completely.

Most ordinary transforms are invertible, so this is usually something you simply keep in mind rather than design around.

## From one node to another

Going through global coordinates yourself would work, but GraphX can translate directly between two nodes on the same stage:

```dart
final pointInHud = player.localToNode(
  hud,
  20,
  0,
);
```

Read that as:

> Where is the point `(20, 0)` from `player` when described in `hud`'s coordinate space?

That question turns up constantly in visual work.

Maybe `(20, 0)` is the end of a character's arm. Maybe it is the muzzle of a ship. Maybe it is the anchor for a tooltip. The hierarchy can be completely different on each side; GraphX follows the transforms for you.

## Points and movement are slightly different

A point has a position. A movement does not.

If you are translating a direction or delta — perhaps a drag amount — use the delta form:

```dart
final dragInPanel = card.localDeltaToNode(
  panel,
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

## A useful way to think about it

You do not need to mentally multiply matrices every time two objects need to talk.

Ask two questions instead:

1. **What space is this point in now?**
2. **What space do I need it in?**

Then choose the conversion that says exactly that.

Once that habit clicks, nested transforms become much less mysterious.
