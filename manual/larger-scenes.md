# Building larger scenes

`GraphXView.scene(...)` is a good place to start. The whole idea is visible at once, and for small experiments that can be exactly what you want.

Eventually a scene may stop feeling like an experiment.

It gets state. It has setup and cleanup. It reacts to resizing. Other parts of the Flutter app need to talk to it. At that point, putting everything inside one callback is usually not the interesting part anymore.

GraphX has another form for that.

## Give the scene a root class

A larger scene can be represented by your own `GRoot`:

```dart
class GameScene extends GRoot {
  @override
  void attached() {
    final card = addChild(GShape(name: 'card'));

    card.graphics
        .beginFill(Colors.red)
        .drawRoundRect(0, 0, 180, 80, 20)
        .endFill();

    card.alignPivot(0, 0, preserve: false);
    card.setPosition(180, 160);
  }
}
```

Then Flutter creates that root for the view:

```dart
GraphXView(
  root: GameScene.new,
)
```

Nothing fundamental changed. `GameScene` is still the root of the same kind of scene tree we have already been using.

What changed is where the scene gets to live.

Instead of growing one callback forever, it now has a class where related state and behavior can stay together.

## The callback form is not the "toy" form

There is no prize for turning every scene into a class.

This is perfectly fine:

```dart
GraphXView.scene((root) {
  // build the scene
});
```

And so is this:

```dart
GraphXView(
  root: GameScene.new,
);
```

Use the form that makes the scene easier to understand.

The callback form is excellent for examples, small visual pieces, prototypes, and scenes that naturally fit in one place. A `GRoot` subclass becomes useful when the scene wants its own lifecycle or has enough behavior to deserve a home of its own.

## A root has a lifecycle

Once you have a root class, GraphX gives it a few useful moments to respond to.

`attached()` runs when the root is attached to a usable stage:

```dart
@override
void attached() {
  // Build or connect the scene here.
}
```

If the viewport changes, `resize()` is available too:

```dart
@override
void resize(double width, double height) {
  // Reposition anything that depends on the viewport.
}
```

There is also `detached()` for cleanup tied to attachment.

We will cover lifecycle properly later. The important thing here is simply that a larger scene does not need to invent its own place for this work.

## `GraphXView` has a few useful handles

Both forms of `GraphXView` can take a `controller`, a `value`, and a `config`.

You can ignore all three until you need them.

### Controller

A `GraphXController` gives Flutter-side code access to an attached root:

```dart
final controller = GraphXController<GameScene>();

GraphXView(
  root: GameScene.new,
  controller: controller,
)
```

Once attached, `controller.root` is the actual `GameScene` instance.

That is useful when a Flutter control needs to tell a scene to do something without turning the scene itself into widget state.

### Value

`value` is a bridge for application data supplied by the Flutter side:

```dart
GraphXView(
  root: GameScene.new,
  value: gameState,
)
```

The root can consume Flutter synchronization when that data or inherited Flutter dependencies change. We will give that its own example in the Flutter integration chapter; there is no need to use it for ordinary scene state.

### Config

`GraphXConfig` changes how the view integrates with Flutter and the stage:

```dart
GraphXView(
  root: GameScene.new,
  config: const GraphXConfig(
    keyboard: true,
    autofocus: true,
  ),
)
```

The current options are deliberately small:

- `reloadMode` — retain the current scene during hot reload, or restart it.
- `repaintBoundary` — whether the GraphX surface is its own Flutter repaint boundary.
- `maxDelta` — clamps unusually large frame deltas.
- `pointer` — enables pointer input from the Flutter surface.
- `hitTestBehavior` — claim the whole view or only interactive GraphX content.
- `keyboard` — capture raw keyboard input.
- `autofocus` — request Flutter focus when the surface attaches.

Most scenes should start with the defaults.

There is one useful distinction already built in: the class-based `GraphXView` defaults to retaining its scene during hot reload, while `GraphXView.scene(...)` defaults to restarting its callback scene. Those defaults match the usual reason you picked each form in the first place.

## Start simple, grow when it helps

You do not need to design the final architecture before drawing the first circle.

Start with the callback when it makes the idea obvious. Move to a root class when the scene starts asking for one.

The scene model stays the same either way, which means learning the simple form is not throwaway knowledge. It is the same GraphX, just with a different place to organize the work.
