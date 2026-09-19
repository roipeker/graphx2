# Flutter assets

GraphX does not need a second bundle format for ordinary Flutter files.

If an image is already declared as a Flutter asset, `GAssets` can read and decode it from the same asset bundle.

## Use the normal Flutter asset bundle

A Flutter project still declares files in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - images/player.png
    - images/explosion.gif
```

Then an attached GraphX scene can ask its runtime store for them:

```dart
final texture = await stage.assets.texture(
  'images/player.png',
);
```

If no bundle is supplied, GraphX uses Flutter's `rootBundle`.

Nothing GraphX-specific has to be added to the asset manifest.

## Choose the result you actually need

The bundle helpers differ by what they return.

Raw bytes:

```dart
final bytes = await stage.assets.bytes('data/level.bin');
```

A single texture:

```dart
final texture = await stage.assets.texture('images/player.png');
```

A timed animation sequence:

```dart
final sequence = await stage.assets.textureSequence(
  'images/explosion.gif',
);
```

Or let GraphX preserve whether decoded image data is static or animated:

```dart
final imageData = await stage.assets.image(
  'images/explosion.gif',
);
```

`image()` returns `GTextureData`: a static source becomes `GTexture`, while a multi-frame codec becomes `GTextureSequence`.

`texture()` intentionally asks for one `GTexture`; if the source format is animated, it resolves the first frame.

That distinction lets call sites say what they mean instead of discovering animation by accident later.

## Loading and displaying remain separate

Loading does not put anything into the scene:

```dart
final texture = await stage.assets.texture('images/player.png');
```

Rendering begins when a node uses it:

```dart
final player = addChild(GImage(texture));
player.setPosition(120, 80);
```

That separation is what lets one decoded texture feed several `GImage` nodes without duplicating the resource.

It also keeps the async boundary away from rendering itself: decoding can finish whenever it finishes; once available, the retained node paints the texture normally.

## Async work can outlive a node

An asset decode may complete after the scene object that requested it has been removed or disposed.

When the result is going to mutate a specific node/root, check that the owner still exists:

```dart
Future<void> loadPlayer() async {
  final texture = await stage.assets.texture('images/player.png');
  if (isDisposed || !isAttached) return;

  addChild(GImage(texture));
}
```

The texture can remain valid in the runtime cache even though this particular consumer disappeared.

That is another reason resource lifetime and node lifetime are separate concepts.

## Decode size can be intentional

For large source images, Flutter's image codec can decode toward a target size:

```dart
final thumbnail = await stage.assets.texture(
  'images/photo.jpg',
  targetWidth: 256,
);
```

`targetWidth` and `targetHeight` are passed into Flutter's image codec rather than resizing the already-decoded texture afterwards.

A thumbnail request and a full-size request receive different cache entries because their decoded resources are genuinely different.

This can matter much more than scaling a giant image down at render time when memory is the real constraint.

## A custom `AssetBundle` is still possible

Every Flutter-bundle loader accepts an optional bundle:

```dart
final texture = await stage.assets.texture(
  'images/player.png',
  bundle: myBundle,
);
```

That is useful for tests, custom bundle sources, or applications that already have a Flutter `AssetBundle` abstraction they want GraphX to respect.

The bundle itself also participates in cache identity, so the same path from two different bundles is not silently treated as one resource.

## `ImageProvider` is the Flutter escape hatch

Sometimes the source already exists as a Flutter `ImageProvider` instead of a bundle path.

GraphX can resolve it and snapshot the resulting image into an independently-owned texture:

```dart
final texture = await stage.assets.imageProvider(
  provider,
);
```

This is an integration escape hatch, not a requirement to route all images through Flutter widgets. Once resolved, the result is a normal `GTexture` that can be used by retained GraphX nodes.

Next we will look at sources that start outside the Flutter bundle entirely: in-memory bytes and network URLs.
