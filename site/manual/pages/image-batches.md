# Image batches

A thousand sparks do not necessarily need a thousand scene nodes.

If every spark only needs a texture, position, rotation, scale, alpha, and color, a full node hierarchy can be more machinery than the problem requires.

`GImageBatch` is the deliberate lightweight path.

## Many sprites, one GraphX node

```dart
final batch = root.addChild(
  GImageBatch(capacity: 1000),
);

for (var i = 0; i < 500; i++) {
  batch.add(
    sparkTexture,
    x: GMath.random() * stage.width,
    y: GMath.random() * stage.height,
    scale: 0.5 + GMath.random(),
  );
}
```

The batch itself is a normal `GNode`.

Its entries are `GImageInstance`s, intentionally **not** nodes.

That distinction is the optimization.

## An instance keeps only the sprite-level state

```dart
final spark = batch.add(sparkTexture);

spark.setPosition(120, 80);
spark.rotation = 0.4;
spark.scale = 0.8;
spark.alpha = 0.6;
spark.color = Colors.cyan;
```

An instance has no child list, pointer router, lifecycle callbacks, masks, filters, focus state, semantics, or independent compositing tree.

If an image needs those things, use `GImage`.

If it only needs to be one lightweight textured element inside a larger batch, use `GImageInstance`.

That is a much better rule than “batching is always faster.”

## The batch uses Flutter's atlas draw path

Internally, GraphX packs instance transforms/source rectangles/colors into flat buffers and paints compatible runs with Flutter Canvas `drawRawAtlas()`.

So instead of conceptually doing:

```text
paint image node
paint image node
paint image node
paint image node
...
```

GraphX can hand many sprite transforms to the canvas in one atlas-style operation.

That is why this primitive exists.

## Texture atlases become especially valuable here

Remember the atlas chapter: many `GTexture` regions can point into the same backing `ui.Image`.

`GImageBatch` groups contiguous instances that share one backing image into one draw run.

That means these atlas frames can still batch together:

```text
player_idle  ┐
player_run   ├─ same atlas page / ui.Image
coin         │
spark        ┘
```

The individual `GTexture`s may describe different source rectangles, but the backing image is shared.

If your batch alternates between unrelated backing images repeatedly, GraphX has to split the draw into more runs.

When squeezing performance out of a very large batch, grouping related instances by atlas page can therefore matter.

## The batch still has normal scene behavior

Move the whole batch:

```dart
batch.setPosition(40, 20);
```

or fade it:

```dart
batch.alpha = 0.5;
```

and its lightweight instances remain inside that one retained node.

The batch also computes bounds from its instances, so normal scene geometry still knows the overall extent.

Node-level color transforms/composition are applied to the batch as a unit.

## Individual instances can still animate

```dart
for (var i = 0; i < batch.length; i++) {
  final sprite = batch[i];
  sprite.y += 40 * delta;
  sprite.rotation += delta;
}
```

Instance mutation updates the packed buffers directly rather than turning each sprite into a scene node.

That is a good fit for:

```text
particles
star fields
tile decorations
crowds of simple sprites
bullet fields
confetti
```

## Removal invalidates the handle

```dart
spark.remove();
```

Once removed, that `GImageInstance` is detached from the batch and should not be mutated again.

Check:

```dart
spark.isAttached
```

if code may outlive the instance.

This `isAttached` means “still owned by its batch,” not GraphX stage attachment; remember that a `GImageInstance` is not a `GNode`.

## This is a specialization, not the default image type

Use `GImage` first when the object has identity in your scene.

Reach for `GImageBatch` when you can truthfully say:

> these hundreds/thousands of images do not need to be independent nodes.

That sentence is the optimization contract.

You are trading node-level flexibility for a much denser representation and a better Canvas submission path.
