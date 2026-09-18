# Nodes and children

One object is easy. A card, a label, an icon — move it and you are done.

Then you decide the label and icon belong to the card. Moving three things separately would work, but it would get old quickly.

That is what the scene tree is for.

## A node can hold other nodes

Every `GNode` can have children.

Let's make a little badge from a parent node, a background, and a label:

```dart
final badge = root.addChild(GNode(name: 'badge'));

final background = badge.addChild(GShape());
background.graphics
    .beginFill(Colors.blue)
    .drawRoundRect(0, 0, 160, 56, 18)
    .endFill();

final label = badge.addChild(
  GText('GraphX'),
);
```

The tree now looks roughly like this:

```text
root
└── badge
    ├── background
    └── label
```

There is no special container class here. `badge` is simply a node whose useful job is to keep a few related things together.

## Move the group, not the pieces

Now move the parent:

```dart
badge.setPosition(120, 100);
```

The background and label come with it.

Rotate the parent:

```dart
badge.rotation = 0.1;
```

They rotate together too.

A child's transform is relative to its parent. That one rule is behind a lot of useful GraphX behavior.

A character can carry a name tag. A spaceship can carry engines and lights. A camera rig can carry an entire little scene. You arrange the pieces once, then move the thing they belong to.

## Parents and children are ordinary objects

GraphX keeps the relationship explicit:

```dart
print(label.parent == badge); // true
print(badge.numChildren);     // 2
```

You can inspect the children directly:

```dart
final first = badge.getChildAt(0);
```

Or, when you gave one a name, look it up:

```dart
final title = badge.getChildByName('title');
```

Names are optional. They are useful when a human-readable label makes debugging or lookup easier, but you do not need to name every node in a scene.

## A child can move on its own

Being part of a group does not make a child rigid.

```dart
label.setPosition(24, 16);
```

That position is local to `badge`. Move `badge`, and the label still follows. Move `label`, and you only change its place inside the badge.

This is the first important coordinate idea in GraphX: **a node describes itself relative to its parent.**

We will make that much more concrete in the coordinate-space chapter. For now, the tree is enough.

## Moving between parents

A node has one parent at a time. Adding it somewhere else reparents it:

```dart
panel.addChild(label);
```

Now `label.parent` is `panel` instead of `badge`.

And when something should leave the tree completely:

```dart
label.removeFromParent();
```

The relationship changes; the node itself is still the same object.

## Why the tree matters

The scene tree is not just organization. It is how GraphX understands relationships.

Transforms flow through it. Visibility and alpha can affect a whole branch. Input walks the scene. Bounds can include children. Later, masks, caching, focus, semantics, and composition all make more sense once this parent/child model feels ordinary.

You do not need to memorize that list yet.

The useful idea is smaller: **if a few things belong together, give them a parent.**

From here we can start looking at position, scale, rotation, pivot, and the coordinate spaces created by those relationships.
