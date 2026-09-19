# Images and textures

Vector drawing is useful, but sooner or later you want to put actual pixels in the scene.

In GraphX, it helps to separate three ideas:

1. the decoded image data;
2. the texture that describes how that image data should be used;
3. the scene node that renders it.

That sounds more complicated than it is.

## `GImage` is the scene object

Once you have a `GTexture`, showing it is simple:

```dart
final image = root.addChild(GImage(texture));
image.setPosition(120, 80);
```

`GImage` is a normal GraphX node. It can be positioned, scaled, rotated, grouped, hidden, hit-tested, and composed just like the shapes we have already used.

The texture supplies the pixels. The node supplies the place those pixels live in the scene.

## So what is a texture?

Underneath, Flutter renders decoded image data as `dart:ui.Image`.

`GTexture` wraps that image with the extra information a retained scene often needs: logical scale, a frame region, trimming offsets, and whether the frame was rotated inside an atlas.

For a plain image, the relationship is straightforward:

```text
ui.Image  →  GTexture  →  GImage
pixels       image view    scene node
```

This separation is useful because the same texture can be shared by more than one scene node:

```dart
final a = root.addChild(GImage(texture));
final b = root.addChild(GImage(texture));

b.setPosition(120, 0);
b.scale = 0.5;
```

Both nodes render the same underlying image data while keeping independent transforms and scene state.

That is a common graphics-engine pattern and is different from thinking of every displayed image as owning a separate copy of its pixels.

## Loading one from Flutter assets

Most of the time you will not create `GTexture` objects by hand. The GraphX asset store can decode a Flutter asset for you:

```dart
Future<void> addPlayer(GRoot root) async {
  final texture = await root.stage.assets.texture('images/player.png');
  if (root.isDisposed) return;

  final player = root.addChild(GImage(texture));
  player.setPosition(160, 120);
}
```

A callback scene can kick that work off without turning the scene builder itself into an asset-management chapter:

```dart
GraphXView.scene((root) {
  addPlayer(root);
});
```

The `isDisposed` check matters because loading is asynchronous. The Flutter view may have gone away before the image finishes decoding.

We will spend more time on `GAssets` later. It can load from Flutter bundles, memory, URLs, `ImageProvider`, and shared runtimes. For now, the important idea is simply that loading and displaying are separate concerns.

## Logical size and high-resolution assets

A texture can have a logical scale:

```dart
final texture = GTexture(image, scale: 2);
```

If the backing image is 200 × 100 pixels and the texture scale is `2`, GraphX treats it as 100 × 50 logical scene units.

That is useful for `2x`/high-density assets and generated captures where backing pixels and scene size should not be the same thing.

`GImage.width` and `GImage.height` report the texture's logical size, not necessarily the raw pixel dimensions of the backing `ui.Image`.

## One image can contain many textures

Spritesheets and texture atlases pack many images into one larger image.

A `GTexture` can describe just one region of that backing image:

```dart
final iconTexture = texture.region(
  region: GRect(32, 0, 32, 32),
);
```

The new texture still refers to the same underlying `ui.Image`; it simply describes a different frame.

GraphX also keeps frame metadata for trimmed and rotated atlas entries, so a `GImage` can recover the intended logical bounds rather than treating the packed rectangle as the whole object.

You do not need that machinery for ordinary PNGs. It becomes useful once many visual assets need to share a backing texture efficiently.

## Filtering

When an image is scaled, `filterQuality` controls how Flutter samples the texture:

```dart
image.filterQuality = FilterQuality.medium;
```

Lower filtering can be useful for pixel art or when you want the cheapest sampling path. Higher filtering can look smoother when an image is scaled.

There is no universal best choice; it depends on the artwork and how it is being transformed.

## Animated images

GraphX also has `GTextureSequence` and `GAnimatedImage` for timed frame sequences.

A decoded GIF or WebP can become a texture sequence, but the format is intentionally general enough for atlas animations or manually-authored frame clips too.

```dart
final sequence = await root.stage.assets.textureSequence(
  'images/loader.gif',
);
if (root.isDisposed) return;

final loader = GAnimatedImage(sequence);
loader.play();
root.addChild(loader);
```

`GAnimatedImage` is still just a node. Playback changes which texture is rendered over time; transforms, hierarchy, alpha, visibility, and interaction continue to work in the usual GraphX way.

Later, the asset chapters will go deeper into loading, caching, ownership, shared runtimes, and network images. Here the important distinction is smaller:

**`GTexture` is reusable image data; `GImage` is the thing that lives in your scene.**
