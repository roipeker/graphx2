# Your first scene

A blank scene is not very exciting, so let's give it something to do.

We will draw a card, place it on screen, and make it react to a tap. That small example already exercises the core GraphX model.

## Give Flutter a GraphX surface

GraphX lives inside Flutter through `GraphXView`.

```dart
Scaffold(
  body: GraphXView.scene((root) {
    // Our scene goes here.
  }),
);
```

The `root` is the top of the GraphX scene. Everything we add will eventually live under it.

For now, think of it as an empty scene waiting for something to happen.

## Put a shape in the scene

Let's start with a shape:

```dart
final card = root.addChild(GShape(name: 'card'));
```

A `GShape` is a node with a `graphics` object attached to it.

You can think of `graphics` as a little pen and a tiny canvas that belong to the shape. Choose how you want to draw, make a shape or a path, then keep drawing from there.

```dart
card.graphics
    .beginFill(Colors.red)
    .drawRoundRect(0, 0, 180, 80, 20)
    .endFill();
```

The graphics API is fluent on purpose, so a drawing can read as one little sequence. Since this example is sitting inside a Material app, we can also use Flutter's familiar `Colors.red` directly.

We are not going to worry about those coordinates yet. [Coordinate spaces](#coordinate-spaces) gets its own chapter. For now we have a red rounded card.

> `name: 'card'` is optional. A name can be useful as a debug label, and parents can find a direct child later with `getChildByName()`. Leave it out when you do not need one.

## Give it a center

We are going to rotate the card in a moment, and rotating around its center feels more natural.

GraphX can line the pivot up with the center of the shape for us:

```dart
card.alignPivot(0, 0, preserve: false);
```

You do not need to understand pivots yet. Think of this as choosing the point the card will turn around. We will come back to it in [Position, scale, rotation, and pivot](#position-scale-rotation-and-pivot).

## Put it somewhere

Now place the card in the scene:

```dart
card.setPosition(180, 160);
```

`setPosition()` is a convenient way to set `x` and `y` together. You can also change them individually whenever that reads better:

```dart
card.x = 180;
card.y = 160;
```

If you are coming from Flutter, there is something worth noticing here: **there is no `setState()`**. The card is a retained object in the GraphX scene. Change its transform and GraphX knows that the scene needs to be painted again.

## Make it interactive

At this point we have something on screen. Let's make it respond to us.

```dart
card.pointer.onTap.add((_) {
  card.rotation += 0.15;
});
```

Tap the card and it turns a little around the center we chose earlier.

The same object we drew is the object we positioned and the object receiving the pointer event. That direct relationship is a useful part of the GraphX scene model.

## The example in one place

```dart
GraphXView.scene((root) {
  final card = root.addChild(GShape(name: 'card'));

  card.graphics
      .beginFill(Colors.red)
      .drawRoundRect(0, 0, 180, 80, 20)
      .endFill();

  card.alignPivot(0, 0, preserve: false);
  card.setPosition(180, 160);

  card.pointer.onTap.add((_) {
    card.rotation += 0.15;
  });
});
```

We created a node, drew into it, positioned it, and gave it an interaction. Those ideas will keep showing up as scenes become more interesting.

## One object, three jobs

There are already a few relationships hiding inside that example.

`card` is a child of `root`. Its position belongs to that relationship. Its drawing belongs to the card itself. Its pointer listener belongs to the same card too.

We will make those relationships visible in [Nodes and children](#nodes-and-children) by putting several objects under the same parent. That is where the scene tree starts earning its keep.
