# Bounds

Bounds are the cheap geometric answer to questions that do not need the exact path.

An editor wants a selection rectangle around a whole diagram item. A culler wants to reject an offscreen branch. A hit-test helper needs a quick broad-phase box before doing something more exact.

All three are asking for some version of: **what rectangle contains this geometry in the coordinate space I care about?**

## `localBounds` includes the subtree

For most scene work, start with `localBounds`:

```dart
final bounds = item.localBounds;

print(bounds.width);
print(bounds.height);
```

These bounds are expressed in `item`'s own coordinate space and include the visual geometry of its descendants.

So if a child sits 200 pixels to the right, the parent's local bounds grow to include it.

## The node itself

Sometimes you want only the geometry owned by the node, without any children:

```dart
final bounds = shape.selfBounds;
```

For a `GShape`, that means the geometry drawn into its `graphics` object.

`selfBounds` does not include descendants and does not apply the node's own transform. Think of it as the intrinsic box of the thing itself.

That distinction becomes useful for layout code and custom nodes where "my geometry" and "my whole subtree" are different questions.

## Ask in another coordinate space

Bounds can also be described relative to another node on the same stage:

```dart
final boundsInRoot = item.getBounds(root);
```

GraphX follows the transforms through the hierarchy and gives you an axis-aligned `GBounds` in the target node's coordinate space.

If you remember Flash's `DisplayObject.getBounds(targetCoordinateSpace)`, this is the same family of question. In Flutter terms it is closer to asking a `RenderBox` about paint/layout geometry after converting between render-object coordinate spaces.

The geometry is the same; the numbers depend on the space you ask the question in.

## Reading a `GBounds`

A bounds object stores its four edges:

```dart
bounds.x1;
bounds.y1;
bounds.x2;
bounds.y2;
```

and provides the common conveniences:

```dart
bounds.width;
bounds.height;
bounds.isEmpty;
bounds.contains(x, y);
bounds.intersects(other);
```

An empty node can have empty bounds. That is normal; a plain `GNode` with no visual descendants has nothing to measure yet.

## Bounds describe geometry, not visibility

Bounds describe scene geometry, not whether a branch happens to be painted right now.

If you hide a child with `visible = false`, its geometry still belongs to the scene tree and can still contribute to its parent's bounds.

That makes bounds stable as a geometric description instead of changing simply because something was temporarily hidden.

When what you really want is "is this participating right now?", [Visibility and activity](#visibility-and-activity) answer a different question.

## Bounds become building blocks

Bounds quietly support a lot of higher-level features: pivot alignment, hit areas, viewport culling, focus navigation, filters, caches, snapshots, and inspection tools.

You usually do not need to manage them yourself. GraphX keeps the retained bounds state up to date as the scene changes.

The question to ask is: **this node, this subtree, and in which coordinate space?**
