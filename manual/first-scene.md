# Your first scene

A blank scene is not very exciting, so let's give it something to do.

We will make a small card, put it somewhere on screen, and make it react when you tap it. Nothing fancy yet. The point is to see how little code it takes to get something alive inside GraphX.

## Start with a place to draw

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

## Add something

A `GShape` is a node that can draw vector graphics.

```dart
final card = root.addChild(GShape(name: 'card'));
```

The important part here is not the name. It is `addChild`.

GraphX scenes are made from nodes connected as a tree. We just added our first node to that tree.

Now give it something to draw:

```dart
card.graphics
    .beginFill(const Color(0xff6750a4))
    .drawRoundRect(-90, -40, 180, 80, 20)
    .endFill();
```

`graphics` is intentionally fluent, so drawing commands can read like a little sequence.

We drew the rectangle around `(0, 0)`. That gives the card a useful center, which will become more interesting when we start rotating and scaling things later.

## Put it somewhere

New nodes begin at the origin of their parent. We can move the card by changing its position:

```dart
card.x = 180;
card.y = 160;
```

That is one of the basic pleasures of a scene model: the object stays there, and you change the properties you care about.

No rebuild is needed just to say, "move this over here."

## Make it react

A picture is nicer once it notices you.

```dart
card.pointer.onTap.add((_) {
  card.rotation += 0.15;
});
```

Tap the card and it turns a little.

That tiny interaction already tells us something useful about GraphX: the thing you drew is also the thing you move and the thing that receives input.

## Put it together

The whole scene is still small:

```dart
GraphXView.scene((root) {
  final card = root.addChild(GShape(name: 'card'));

  card.graphics
      .beginFill(const Color(0xff6750a4))
      .drawRoundRect(-90, -40, 180, 80, 20)
      .endFill();

  card.x = 180;
  card.y = 160;

  card.pointer.onTap.add((_) {
    card.rotation += 0.15;
  });
});
```

That is enough for a first scene.

We created one node, drew into it, positioned it, and gave it behavior. Most larger GraphX scenes are built from the same ideas; they just have more nodes and more interesting relationships between them.

## One small thing to notice

The card's drawing is centered around its own origin, while `x` and `y` position that origin inside the parent.

That distinction is going to matter a lot. It is what makes grouping, rotation, scaling, nested scenes, and coordinate conversion feel predictable later.

For now, you only need the intuition: **draw locally, place the object in the scene.**

Next we will look at nodes and children, and why moving one parent can move an entire little world with it.
