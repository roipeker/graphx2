# Position, scale, rotation, and pivot

Once something exists in a scene, the next question is usually some version of: **where should it go?**

GraphX gives every node a transform. That is the small group of properties that describes where the node is, how large it is, and which way it is facing relative to its parent.

## Position

You have already used this one:

```dart
card.setPosition(180, 160);
```

It is shorthand for setting the two position properties together:

```dart
card.x = 180;
card.y = 160;
```

The important detail is *relative to its parent*.

If `card` is a child of `panel`, then `(180, 160)` means 180 across and 160 down inside `panel`'s coordinate space. Move `panel`, and the card comes with it.

That parent relationship is why the scene tree from [Nodes and children](#nodes-and-children) matters so much.

For Flutter users, `setPosition()` is closer in spirit to positioning something in a `Stack` or using `Transform.translate` than to normal widget layout. The node already exists; you are changing where its retained scene transform places it.

## Scale

Scale changes the size of a node without changing the geometry you originally drew.

```dart
card.scale = 1.25;
```

A scale of `1` is the original size. `2` is twice as large. `0.5` is half the size.

If you have used Flutter's `Transform.scale`, the idea is the same. In GraphX the scale lives directly on the node instead of being another widget wrapped around it.

`scale` is the convenient uniform form. When the two axes need to be different, use `setScale()` or the individual properties:

```dart
card.setScale(1.5, 0.8);
```

which corresponds to:

```dart
card.scaleX = 1.5;
card.scaleY = 0.8;
```

Usually uniform scale is easier to reason about. Uneven scale is there when you actually want the stretch.

## Rotation

Rotation is an angle in radians, just like Flutter's `Transform.rotate`.

Standard Dart math works exactly as you would expect:

```dart
import 'dart:math' as math;

card.rotation = math.pi / 4;
```

That turns the card 45 degrees.

GraphX also exposes `GMath`, a small creative-coding math toolbox. When you are already working inside GraphX, the same rotation can avoid the extra import:

```dart
card.rotation = GMath.quarterPi;
```

or, when degrees are easier to read:

```dart
card.rotation = GMath.radians(45);
```

Both styles are fine. `dart:math` is the standard Dart library; `GMath` adds convenient constants and helpers such as `tau`, `halfPi`, `quarterPi`, angle wrapping, interpolation, `hypo()`, and degree/radian conversion.

For tiny interactions it is also common to add a little rotation at a time:

```dart
card.rotation += 0.15;
```

Radians can feel strange if you first learned angles in degrees. [Angles, sine, and cosine](#angles-sine-and-cosine) gives them a visual explanation. For now, `math.pi` is half a turn and `math.pi * 2` is one complete turn.

## The point things turn around

Here is where pivots become useful.

Imagine pinning a piece of paper to a wall. The paper rotates around the pin. Move the pin to a corner and the motion changes. Put it in the center and the paper spins around its middle.

A GraphX pivot is that pin.

Flutter's `Transform` has related ideas through `alignment` and `origin`: they influence the point around which a transform is applied. GraphX keeps that registration point directly on the node as `pivotX` and `pivotY`.

By default the pivot is `(0, 0)` in the node's local coordinates.

You can set it directly:

```dart
card.setPivot(90, 40);
```

But when what you really mean is "use the center of whatever this node contains," GraphX can work that out from its bounds:

```dart
card.alignPivot(0, 0);
```

For `alignPivot()`, `-1` means the left or top edge, `0` means center, and `1` means the right or bottom edge.

So these are all useful positions:

```dart
card.alignPivot(-1, -1); // top-left
card.alignPivot(0, 0);   // center
card.alignPivot(1, 1);   // bottom-right
```

## Why `preserve` exists

There is a small practical detail hiding here.

If a node is already placed on screen and you change its pivot, you often do **not** want the visible artwork to jump somewhere else. That is why `alignPivot()` preserves the complete local transform by default.

```dart
card.alignPivot(0, 0);
```

The pivot moves to the center while GraphX compensates the position so the card stays visually where it was.

When you are setting up a new node and plan to position it afterwards, you can opt out of that compensation:

```dart
card.alignPivot(0, 0, preserve: false);
card.setPosition(180, 160);
```

That is the pattern we used in [Your first scene](#your-first-scene).

## When you meet the matrix

Most of the time, `x`, `y`, `scale`, `rotation`, `skew`, and pivot are the nicest way to work.

Underneath them is a 2D affine transform. GraphX exposes that as `GMatrix2` when you need the lower-level representation directly.

If you have used Flutter's:

```dart
Transform(
  transform: someMatrix4,
  child: child,
)
```

this is the same broad idea. The matrix encodes how coordinates are translated, scaled, rotated, or skewed. GraphX uses a compact 2D affine matrix because the scene model is 2D.

You can assign a `localMatrix` or use `setLocalMatrixValues()` when importing or streaming matrix data directly. For ordinary authored scenes, the scalar transform properties are usually much easier to read.

## Transforms travel down the tree

The useful part is that these properties compose through the hierarchy.

```dart
final group = root.addChild(GNode());
final card = group.addChild(GShape());

card.setPosition(80, 0);
group.setPosition(200, 160);
group.rotation = 0.2;
group.scale = 1.3;
```

The card keeps its own local position inside `group`, while the group's position, rotation, and scale affect the card as part of the branch.

This is what lets a complex scene stay understandable. A wheel can rotate inside a car while the whole car moves. A hand can rotate around an arm while the character moves across the screen. Each piece only needs to know about the space it lives in.

That leads naturally to [Coordinate spaces](#coordinate-spaces) — how GraphX translates a point from one part of the tree into another.
