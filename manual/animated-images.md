# Animated images

A GIF is not special because it is a GIF.

What the scene actually needs is simpler: **an ordered sequence of textures, each with a duration.**

That is `GTextureSequence`.

## One sequence, many possible sources

A sequence can come from an animated image file:

```dart
final sequence = await stage.assets.textureSequence(
  'images/loader.gif',
);
```

or WebP, memory bytes, a URL, an atlas, or frames you assembled yourself.

GraphX deliberately separates the playback model from the source format:

```text
GIF / WebP / atlas / manual frames
              ↓
       GTextureSequence
              ↓
        GAnimatedImage
```

Once the frames are a sequence, playback code no longer cares where they came from.

## Put the sequence in the scene

```dart
final loader = root.addChild(
  GAnimatedImage(sequence),
);

loader.play();
```

`GAnimatedImage` is a normal retained node. Move it, scale it, fade it, put children under it, give it a hit area—the playback only changes which texture frame is currently rendered.

```dart
loader.setPosition(120, 80);
loader.scale = 2;
loader.alpha = 0.9;
```

## Frame timing belongs to the sequence

Each frame carries its own duration:

```dart
GTextureSequenceFrame(
  texture,
  const Duration(milliseconds: 90),
)
```

That matters because not every animation uses uniform timing.

A character blink might hold the open-eye frame for 700 ms and the closed-eye frame for only 80 ms. A decoded GIF can preserve those original per-frame delays without flattening them into an arbitrary frame rate.

The total sequence duration is available too:

```dart
print(sequence.duration);
```

## Build one from atlas frames

A texture atlas can turn named regions into a timed sequence:

```dart
final run = atlas.sequence(
  [
    'player/run-1',
    'player/run-2',
    'player/run-3',
    'player/run-4',
  ],
  frameDuration: const Duration(milliseconds: 85),
);
```

Then:

```dart
final player = GAnimatedImage(run);
player.play();
```

No GIF decoder is involved. The frames are borrowed `GTexture` views into the atlas pages.

That is why `GTextureSequence` is intentionally format-agnostic: sprite animation and animated image files can share the same playback node.

## Stop, jump, continue

```dart
player.stop();
```

keeps the current frame visible and stops playback advancement.

Jump to an exact frame:

```dart
player.gotoFrame(2);
```

or combine the two operations:

```dart
player.gotoAndStop(0);
player.gotoAndPlay(3);
```

The current frame is also exposed directly:

```dart
print(player.currentFrame);
print(player.currentTexture);
```

Frame indexes are zero-based.

## Looping or one-shot playback

Looping is on by default:

```dart
player.loop = true;
```

For an explosion that should play once:

```dart
explosion.loop = false;
explosion.play();
```

Listen for completion:

```dart
explosion.onComplete.add(() {
  explosion.removeFromParent();
});
```

There is a separate loop signal when repeating animations need a beat at the wrap point:

```dart
player.onLoop.add(() {
  print('another lap');
});
```

And frame changes can be observed too:

```dart
player.onFrame.add((frame) {
  if (frame == 2) {
    playFootstep();
  }
});
```

That can be useful for small animation-driven events, although a large character-animation system may eventually want richer authored metadata than hard-coded frame numbers.

## Speed up or slow down playback

```dart
player.playbackRate = 2.0;
```

plays twice as fast.

```dart
player.playbackRate = 0.5;
```

plays at half speed.

The rate scales elapsed update time; it does not rewrite the sequence's stored frame durations.

A rate of `0` stops frame advancement without changing the `playing` flag. Calling `stop()` is clearer when the semantic intent is explicitly “stop playback.”

## Animated images only keep the frame loop alive when needed

`GAnimatedImage` uses the same `updatesEnabled` mechanism we learned in [Frame updates](#frame-updates).

It registers for frame updates only when all of these are true:

```text
playing
playbackRate > 0
sequence exists
sequence has more than one frame
sequence has non-zero duration
```

Stop it, set a one-frame sequence, or finish a non-looping animation and that node no longer needs continuous update work.

So a paused sprite does not keep GraphX ticking merely because it happens to be an animated-image class.

That demand-driven behavior is built into the primitive.

## Different frame sizes are allowed

Each sequence frame can reference a texture with different logical dimensions.

When the current frame changes size, `GAnimatedImage` invalidates its bounds so scene geometry stays correct.

That is useful for trimmed atlas frames, but it can also make alignment appear to jump if the authored frame metadata does not preserve a consistent logical frame rectangle.

Atlas trimming metadata exists precisely to keep a small packed rectangle positioned inside the intended logical frame.

## Filtering works like `GImage`

```dart
player.filterQuality = FilterQuality.none;
```

can be appropriate for crisp pixel art.

Higher filtering may look better for smoothly scaled photographic/illustrated animation.

Playback does not change the image-sampling rules.

## The node does not own the sequence

Disposing this:

```dart
player.dispose();
```

does not dispose its `GTextureSequence`.

That is intentional because several animated nodes may use the same sequence, and cached asset sequences belong to the runtime asset store.

For a sequence returned from cached `stage.assets` loading, runtime/cache ownership handles its lifetime.

For a manually-created owned sequence that nobody else owns, your code should eventually dispose the sequence:

```dart
sequence.dispose();
```

If the sequence was created with `ownsTextures: true`, disposing it also disposes its frame textures.

Again, node lifetime and asset lifetime are separate.

## A sprite sheet becomes motion when time enters the picture

The retro atlas diagram earlier showed several frames sitting beside each other in one image.

`GTextureAtlas` gives those regions names.

`GTextureSequence` gives them order and duration.

`GAnimatedImage` gives them playback inside the retained scene.

That progression is a nice example of GraphX keeping data responsibilities small:

```text
texture region  → what pixels?
sequence        → which frame, for how long?
animated node   → where does it live and play in the scene?
```

No one object needs to know everything.
