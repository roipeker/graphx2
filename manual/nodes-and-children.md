# Nodes and children

Scene objects rarely stay single-purpose for long.

A node in a diagram may have a body, a title, connection ports, selection handles, and status decoration. Those pieces should not need independent world-position bookkeeping every time the item moves.

That is what the scene tree is for.

## A node can hold other nodes

Every `GNode` can have children.

Build one diagram item from several retained parts:

```dart
final item = root.addChild(GNode(name: 'node-17'));

final body = item.addChild(GShape());
body.graphics
    .beginFill(Colors.blueGrey)
    .drawRoundRect(0, 0, 180, 96, 14)
    .endFill();

final title = item.addChild(GText('Input'));
title.name = 'title';
title.setPosition(18, 14);

final outputPort = item.addChild(GShape());
outputPort.graphics
    .beginFill(Colors.orange)
    .drawCircle(0, 0, 7)
    .endFill();
outputPort.setPosition(180, 48);
```

The hierarchy is explicit:

```text
root
└── node-17
    ├── body
    ├── title
    └── outputPort
```

There is no separate container widget. `item` is simply a node that establishes the local coordinate system shared by the parts of one scene object.

## Move the object once

Position the parent:

```dart
item.setPosition(320, 180);
```

The title and port follow because their coordinates are local to `item`.

Rotate the item:

```dart
item.rotation = 0.1;
```

The whole branch rotates around the same retained transform hierarchy.

That is the practical value of parent/child transforms: authored relationships stay authored. A port remains on the edge of its node; a selection handle remains attached to its object; an overlay rig can carry several coordinated visuals without recomputing all of their world positions manually.

## Parents and children are ordinary objects

GraphX keeps the relationship explicit:

```dart
print(title.parent == item); // true
print(item.numChildren);     // 3
```

You can inspect the children directly:

```dart
final first = item.getChildAt(0);
```

Or, when you gave one a name, look it up:

```dart
final found = item.getChildByName('title');
```

Names are optional. They are useful when a human-readable label makes debugging or lookup easier, but you do not need to name every node in a scene.

## A child can move on its own

Being part of a group does not make a child rigid.

```dart
outputPort.setPosition(180, 48);
```

That position is local to `item`. Move `item`, and the port still follows. Move `outputPort`, and you only change where that port sits inside the diagram item.

This is the first important coordinate idea in GraphX: **a node describes itself relative to its parent.**

We will make that much more concrete in the coordinate-space chapter. For now, the tree is enough.

## Moving between parents

A node has one parent at a time. Adding it somewhere else reparents it:

```dart
otherItem.addChild(outputPort);
```

Now `outputPort.parent` is `otherItem` instead of `item`.

And when something should leave the tree completely:

```dart
outputPort.removeFromParent();
```

The relationship changes; the node itself is still the same object.

## Parent once, move the group

The scene tree is not just organization. It is how GraphX understands relationships.

Transforms flow through it. Visibility and alpha can affect a whole branch. Input walks the scene. Bounds can include children. Later, masks, caching, focus, semantics, and composition all make more sense once this parent/child model feels ordinary.

You do not need to memorize that list yet.

The rule is small: **if a few things belong together, give them a parent.**

From here we can start looking at position, scale, rotation, pivot, and the coordinate spaces created by those relationships.
