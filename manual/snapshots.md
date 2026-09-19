# Snapshots

Sometimes you want to take a retained subtree and say:

> give me the pixels **right now**.

That is a snapshot.

## Turn a node into a texture

```dart
final texture = await badge.snapshot();
```

The result is a fresh owned `GTexture` containing the rendered node and its descendants.

Now it can be used like any other texture:

```dart
final preview = root.addChild(GImage(texture));
preview.setPosition(40, 40);
```

Because the returned texture is owned by the caller, dispose it when that snapshot is no longer needed:

```dart
texture.dispose();
```

## Snapshot coordinates are local to the node

Suppose the node itself lives at:

```dart
badge.setPosition(300, 180);
badge.rotation = GMath.radians(20);
```

Those outer scene-placement transforms are intentionally **not** baked into `badge.snapshot()`.

The snapshot starts from the badge's own local coordinate system.

Descendant transforms remain, because they are part of what the badge contains.

That distinction makes a snapshot reusable: moving the original badge somewhere else in the stage should not create a giant texture with 300 pixels of empty space before its artwork.

## Visual composition is preserved

The snapshot keeps the visual state that belongs to the subtree itself:

```text
node alpha
color transform
clip
mask
filters
descendant transforms/composition
```

So a glowing, masked, colorized badge snapshots as the thing you actually see—not as its raw uncomposited ingredients.

When `area` is omitted, GraphX uses effect bounds so outer blur/shadow pixels are not cropped away.

## Capture an exact local rectangle

```dart
final texture = await node.snapshot(
  area: GRect(20, 10, 160, 90),
);
```

`area` is in that node's local coordinate space.

This is handy for export tools, thumbnails, cropping a region of a larger retained drawing, or generating temporary drag previews.

## `scale` controls backing resolution

```dart
final texture = await node.snapshot(scale: 2.0);
```

The logical GraphX size remains the same, but the backing image gets two pixels per logical unit.

For a 100×50 logical snapshot:

```text
scale 1 → 100 × 50 pixels
scale 2 → 200 × 100 pixels
scale 3 → 300 × 150 pixels
```

This is the same distinction we saw with texture logical size: backing pixels and scene-space dimensions are not required to be identical.

## A node does not have to be on stage

Snapshots also work on detached trees:

```dart
final badge = buildBadge();
final texture = await badge.snapshot(scale: 2);
```

GraphX renders the detached subtree without temporarily attaching it to a fake stage or firing lifecycle hooks.

Masks can still work as long as mask and target belong to the same detached tree.

That makes snapshots useful in asset/build pipelines and tests, not only for things currently visible on screen.

## Snapshot and cache answer different questions

A raster cache says:

> while this retained node stays alive, reuse pixels automatically when they are still valid.

A snapshot says:

> create a **new texture value now** and give ownership to me.

The cache remains connected to the node and invalidates/rebuilds as scene state changes.

A snapshot does not. If the original node changes five seconds later, the texture you captured remains the old pixels until you explicitly take another snapshot.

That makes snapshots great for:

```text
thumbnails
export/share images
transition ghosts
frozen drag previews
visual regression tests
temporary texture generation
```

and caches great for avoiding repeated live rendering work.

Same underlying idea—turn retained content into pixels—but very different lifetime semantics.

## Portals have their own snapshot bridge

A `GPortal` contains a Flutter subtree rather than GraphX-rendered descendants, so it exposes its own `portal.snapshot()` API after Flutter has laid it out and painted it.

Both APIs return `GTexture`, but they capture different rendering worlds:

```text
node.snapshot()   → GraphX subtree
portal.snapshot() → Flutter portal subtree
```

That symmetry is intentional: once the capture is pixels, the rest of GraphX can treat it as an ordinary texture.

## Capture the complete `GraphXView`

A node snapshot captures one GraphX subtree. Sometimes you want the final hosted composition instead:

```dart
final texture = await stage.snapshot();
```

`stage.snapshot()` captures what the attached `GraphXView` produces as a whole:

```text
behind portals
      ↓
GraphX canvas content
      ↓
front portals
```

That makes it the right level for things such as a share/export image of the complete GraphX surface when portals are part of what the user sees.

Unlike `node.snapshot()`, this API requires a stage currently attached to a real `GraphXView` that has completed layout/paint. It is a host capture, not an offstage renderer.

## Stage snapshot coordinates are GraphXView-local

Capture the complete surface:

```dart
final texture = await stage.snapshot();
```

or one stage-local rectangle:

```dart
final texture = await stage.snapshot(
  area: GRect(40, 30, 320, 180),
  scale: 2,
);
```

`area` uses GraphXView/stage logical coordinates and is clipped to the actual hosted view.

As with node snapshots, `scale` controls backing-pixel density while the returned texture keeps logical size information.

## A transform can reframe the capture

`stage.snapshot()` also accepts a `GMatrix2`:

```dart
final transform = GMatrix2();
transform.setValues(
  0.5,
  0,
  0,
  0.5,
  0,
  0,
);

final texture = await stage.snapshot(
  transform: transform,
);
```

The transform maps stage coordinates into snapshot coordinates before the final texture is produced. This can be useful when export code needs to compensate for an existing world/camera transform rather than manually moving the live scene.

A non-identity transform requires an additional raster pass, so use it because the output needs reframing—not as a free default.

## Platform views can make a hosted snapshot impossible

The final `GraphXView` snapshot relies on Flutter being able to rasterize the composed layer tree.

Some platform-view layers are not rasterizable through that path. In that case `stage.snapshot()` throws rather than silently returning an incomplete image.

That limitation belongs to the host composition, not to GraphX node snapshots.

## Three snapshot levels, three different questions

```text
node.snapshot()
  → render this GraphX subtree into new pixels

portal.snapshot()
  → render this Flutter portal subtree into new pixels

stage.snapshot()
  → capture the final hosted GraphXView composition
```

All three return owned `GTexture` values, and all three make the caller responsible for disposing the captured texture when it is finished.

Choosing the level first keeps screenshot/export code much simpler.
