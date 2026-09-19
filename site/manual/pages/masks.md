# Masks

Sometimes you do not want to draw a different shape. You want to take an existing subtree and say:

> only show this part.

GraphX gives you two related tools: **clips** and **masks**.

## A clip is the cheap geometric scissors

A clip cuts the node and its descendants with local geometry:

```dart
photo.clip = GClip.roundRect(
  0,
  0,
  220,
  140,
  24,
);
```

Rectangle, rounded rectangle, and Dart `Path` clips are available:

```dart
node.clip = GClip.rect(0, 0, 200, 120);
node.clip = GClip.path(path);
```

There is also an inverse-path clip when the path should become a hole:

```dart
node.clip = GClip.inversePath(hole);
```

Clips stay on the direct Canvas path; they do not require an offscreen layer by themselves.

Pointer interaction respects the same clip geometry, so a visually clipped-away descendant does not remain mysteriously clickable outside the clip.

## A mask uses another node's rendered alpha

A mask can be much richer than clip geometry because the mask source is itself a GraphX node:

```dart
final photo = root.addChild(GImage(texture));
final mask = root.addChild(GShape());

mask.graphics
    .beginFill(Colors.white)
    .drawCircle(100, 100, 80)
    .endFill();

photo.mask = mask;
```

The target is rendered, the mask node is rendered as alpha coverage, then GraphX keeps only the covered pixels.

The mask's color is not the interesting part. Its **alpha silhouette** is.

A solid red circle and a solid blue circle describe the same coverage if their alpha is the same.

## The mask is a normal scene node

Because the mask is a node, it can move, scale, rotate, animate, contain retained graphics, text, images, or a whole subtree.

```dart
mask.setPosition(40, 0);
mask.rotation = GMath.radians(15);
```

GraphX resolves the mask relative to the target even when they sit under different transforms in the same stage.

That makes effects such as moving spotlights, reveal wipes, soft image-based masks, and animated cutouts natural scene operations rather than manually rebuilt paths.

An active mask source is not also drawn as ordinary scene content. GraphX treats it as mask input while it is being used as a mask.

## Invert the mask for a hole

Normal alpha masking keeps covered pixels:

```dart
photo.maskMode = GMaskMode.alpha;
```

Inverse masking keeps the opposite:

```dart
photo.maskMode = GMaskMode.alphaInverse;
```

A circular mask therefore becomes either a circular window or a circular hole without changing the mask geometry.

## Clip or mask?

Use a clip when the question is geometric and direct:

```text
keep everything inside this rectangle/path
```

Use a mask when the question is pixel coverage:

```text
render this other node/subtree and use its alpha
```

A clip can stay cheap and direct. A mask needs isolation because GraphX must first have target pixels and mask pixels to combine.

That is why `GCompositeMode.auto` creates the required layer automatically when `mask` is assigned.

## Masks do not redefine the target's canonical bounds

A mask changes what pixels survive composition; it does not rewrite the target's retained geometry model.

The same principle will appear again with filters: visual effects may produce fewer or more visible pixels than the canonical scene bounds without forcing transforms, layout math, and hit testing to pretend the original geometry changed.

That separation keeps composition effects from leaking into unrelated scene calculations.
