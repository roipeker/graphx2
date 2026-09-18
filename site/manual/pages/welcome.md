# Welcome to GraphX

GraphX is a 2D scene framework for Flutter.

It is made for the parts of an app that are easier to think about as objects in a scene: interactive graphics, playful interfaces, visual tools, games, diagrams, editors, and custom experiences that do not naturally fit a widget tree.

You create objects, add them to the scene, change their properties, and react to input.

```dart
GraphXView.scene((root) {
  final ball = root.addChild(GShape(name: 'ball'));

  ball.graphics
      .beginFill(Colors.red)
      .drawCircle(0, 0, 40)
      .endFill();

  ball.setPosition(200, 160);

  ball.pointer.onTap.add((_) {
    ball.scale = 1.2;
  });
});
```

That is the basic idea behind most of GraphX.

## A familiar way to think

If you ever worked with Flash's display list, or with a scene library such as PixiJS, some of this will feel familiar. Objects live in a tree. Parents carry their children. Transforms flow down through the scene. You change properties directly and see the result.

GraphX is not trying to recreate either one. It keeps that direct scene model because it is still a very natural way to build visual software, and places it next to Flutter rather than against it.

## Think in scenes

A GraphX scene is a tree of nodes. A node can have children, and its transform affects everything below it.

If you move a container, its children move with it. If you rotate it, the children rotate around it. If you hide it, the whole branch disappears.

This makes groups of visual objects easy to treat as one thing.

```dart
final ship = root.addChild(GNode(name: 'ship'));
final body = ship.addChild(GShape());
final label = ship.addChild(GText('Player'));

ship.x = 300;
ship.y = 200;
ship.rotation = 0.2;
```

You normally work with the scene by changing properties directly. GraphX keeps the scene alive between frames and redraws what is needed.

## GraphX and Flutter

GraphX does not replace Flutter. It lives inside it.

`GraphXView` gives a GraphX scene a place in the Flutter widget tree, so the rest of the application can continue to use normal Flutter layout, navigation, controls, themes, and platform integration.

That means you can use Flutter where widgets make sense and GraphX where a scene makes more sense.

## Where to go next

The next chapters build this up gradually: first the scene tree and transforms, then drawing, images, input, assets, and composition.

You do not need to understand the renderer or the internal runtime to start using GraphX. The public API is the part that matters here.
