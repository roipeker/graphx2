# Scenes are not layouts

If you come from Flutter, there is one difference worth learning early:

**GraphX does not lay out a scene the way Flutter lays out widgets.**

That is not a missing feature. It is one of the reasons a scene can behave so freely.

## Flutter asks where a widget fits

Flutter has a very good layout system.

A parent gives a child constraints. The child chooses a size. The parent decides where the child goes. Widgets such as `Row`, `Column`, `Center`, `Padding`, `Expanded`, and `Stack` build on that conversation.

For application UI, that is extremely useful.

You can say:

```dart
Center(
  child: SizedBox(
    width: 180,
    height: 80,
    child: ColoredBox(color: Colors.red),
  ),
)
```

and let Flutter work out the position.

## GraphX gives you a space

A GraphX node does not ask its parent where it should be laid out.

You put it somewhere:

```dart
card.setPosition(180, 160);
```

If you are thinking in Flutter widgets, the closest everyday analogy is something like `Positioned(left: 180, top: 160)` inside a `Stack`.

The important difference is that `Positioned` participates in Flutter layout. `setPosition()` changes the transform of an object that already lives in the GraphX scene. There is no layout negotiation around it.

Its children are positioned relative to it. Transforms flow through the hierarchy. Nothing is negotiating a `Row` or a `Column` behind the scenes.

That can mean doing a little more arithmetic yourself.

It also means a node can be halfway off screen, overlap five other objects, rotate around an arbitrary pivot, follow a Bézier curve, orbit another node, or fly through a simulation without a layout system trying to reinterpret what you meant.

## Freedom has a price

Suppose you want something centered in a GraphX view.

You may simply calculate it:

```dart
card.setPosition(
  root.stage.width / 2,
  root.stage.height / 2,
);
```

If the view can resize, respond to that too:

```dart
void centerCard() {
  card.setPosition(
    root.stage.width / 2,
    root.stage.height / 2,
  );
}

centerCard();
root.onResize.add((_) => centerCard());
```

That is more explicit than Flutter's `Center` widget.

For a game, diagram, editor, particle system, animated composition, or other visual scene, that explicitness is often exactly what you want. The position is a number you own and can animate, simulate, constrain, or derive however you like.

## Use Flutter where Flutter is better

GraphX is not asking you to rebuild your whole application as coordinates.

A normal app might use Flutter for navigation, forms, buttons, settings, responsive page structure, and accessibility-heavy interface work, then place a `GraphXView` where a freer visual scene belongs.

```dart
Column(
  children: [
    const AppToolbar(),
    Expanded(
      child: GraphXView.scene((root) {
        // A free-form GraphX scene lives here.
      }),
    ),
  ],
)
```

Flutter lays out the application. GraphX handles the scene inside the space Flutter gave it.

That boundary is deliberate.

Later we will also see ways for Flutter widgets and GraphX scenes to meet more closely, including portals and shared Flutter environment state.

## GraphX still gives you structure

No automatic widget-style layout does **not** mean everything is just a pile of magic numbers.

The scene tree gives you parent-relative coordinates. [Position, scale, rotation, and pivot](#position-scale-rotation-and-pivot) give you transforms. [Bounds](#bounds) let you measure visual regions. [Coordinate spaces](#coordinate-spaces) let nodes talk across different branches.

Those are the ingredients you use to build the placement logic that fits the visual problem.

Sometimes that logic is as small as:

```dart
icon.setPosition(12, 12);
```

Sometimes it is a responsive arrangement based on the stage size. Later it may be physics, trigonometry, path following, constraints, or a layout helper built specifically for the kind of scene you are making.

## Layout or direct placement?

When deciding whether something belongs in Flutter or GraphX, this question is often enough:

> Do I want a layout system to decide how this fits, or do I want direct control over where this object is?

There is plenty of overlap, and no rule says an application must choose only one.

GraphX lives inside Flutter precisely so you can use each model where it feels natural.
