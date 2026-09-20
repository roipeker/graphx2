# Welcome to GraphX

GraphX is a retained 2D scene framework that lives inside Flutter.

If you have used Flash's display list, PixiJS containers, SpriteKit nodes, or another scene graph, the family resemblance is immediate: objects stay alive in a tree, parents carry transforms, and you change the scene by changing the objects themselves.

If your background is mostly Flutter, the closest contrast is `CustomPainter`. A painter gives you a canvas and asks you to draw the frame. GraphX keeps the scene objects, hierarchy, transforms, bounds, input state, and rendering data around between frames.

That makes it a good fit for the parts of an application that feel more like a **world** than a **layout**: diagrams, editors, games, interactive graphics, data visuals, playful interfaces, and custom scene-based tools.

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

The shape you drew is the same retained object you positioned and the same object receiving input. There is no second widget representation to keep in sync.

## The lineage is familiar, the host is Flutter

Flash called these things display objects. PixiJS uses containers/display objects. Other engines call them nodes or entities.

GraphX keeps the useful part of that lineage—a direct retained scene tree—but the host platform is still Flutter. `GraphXView` is a widget, Flutter owns the application shell, and GraphX owns the scene inside the rectangle Flutter gives it.

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

One important difference is that GraphX does not run Flutter-style layout inside the scene. You place and transform nodes directly. That tradeoff is important enough to deserve its own short chapter: [Scenes are not layouts](#scenes-are-not-layouts).

## What the next chapters are trying to teach

The first part of the manual builds one mental model: **a retained object lives in a scene, not in Flutter layout**.

From there, transforms, coordinate spaces, bounds, input, drawing, assets, composition, and timing are all consequences of that model rather than unrelated APIs to memorize.

When GraphX introduces a helper that overlaps with Flutter or Dart—`GMath` beside `dart:math`, `GPoint` beside `Offset`, `trace()` beside `print()`—the manual will call out the overlap instead of pretending the GraphX name exists in a vacuum.
