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
);
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

The callback form is excellent for examples, small visual pieces, prototypes, and scenes that naturally fit in one place. It is also useful for mostly static retained scenes: build the geometry once, then let GraphX keep and render it without recreating the drawing on every Flutter paint pass.

For Flutter developers, that can make `GraphXView.scene(...)` an interesting alternative to reaching immediately for `CustomPainter` when the visual wants retained objects, transforms, or interaction rather than a purely paint-time API.

A `GRoot` subclass becomes useful when the scene has enough state and recurring behavior that named methods and overrides make the code easier to organize.

## A root adds root-specific hooks

The node attachment model is covered in [Lifecycle and the stage](#lifecycle-and-the-stage): every `GNode` can override `attached()` and `detached()`, and `stage` is guaranteed there.

`GRoot` adds the host-facing hooks that only make sense at the scene boundary. It receives `resize(width, height)` for viewport changes, `environmentChanged()` for consumed Flutter environment changes, and `reassemble()` when a retained scene survives Flutter hot reload.

That gives a class-based root natural override points while callback scenes can consume the corresponding stage signals.

## Callback scenes have signals

The callback form still has access to the same stage behavior. GraphX exposes signals for the moments that are convenient to consume from a closure:

```dart
GraphXView.scene((root) {
  root.onResize.add((size) {
    // React to a viewport change.
  });

  root.onUpdate.add((delta) {
    // React to a frame update when you need one.
  });
});
```

There are also signals for environment changes and, on the stage, later update phases, Flutter synchronization, inherited Flutter dependencies, reassembly, and disposal.

Those signals are not exclusive to callback scenes. A class-based root can use them too. The difference is mostly one of style: **callbacks are convenient when the whole scene fits comfortably in one place; overrides tend to read better once behavior belongs to a named type.**

## Flutter can keep handles to a retained scene

Both forms of `GraphXView` can take a `controller`, a `value`, and a `config`.

You can ignore all three until you need them.

### Controller

A `GraphXController` gives Flutter-side code access to an attached root:

```dart
final controller = GraphXController<GameScene>();

GraphXView(
  root: GameScene.new,
  controller: controller,
);
```

Once attached, `controller.root` is the actual `GameScene` instance.

That is useful when a Flutter control needs to tell a scene to do something without turning the scene itself into widget state.

### Value

`value` is a bridge for application data supplied by the Flutter side:

```dart
GraphXView(
  root: GameScene.new,
  value: gameState,
);
```

This matters because a GraphX scene is retained. Rebuilding the surrounding Flutter widget does not mean GraphX should throw away the scene tree and build it again.

Instead, the existing scene can consume Flutter synchronization when `value` or inherited Flutter dependencies change. Callback scenes can listen through `root.stage.signals.onFlutterSync`; class-based scenes can organize the same synchronization wherever it makes sense for the root.

[GraphXView](#graphxview) shows the full bridge. The mental model is: **Flutter can rebuild around a GraphX scene while the GraphX scene itself stays alive.**

### Config

`GraphXConfig` changes how the view integrates with Flutter and the stage:

```dart
GraphXView(
  root: GameScene.new,
  config: const GraphXConfig(
    keyboard: true,
    autofocus: true,
  ),
);
```

The current options are deliberately small:

- `reloadMode` — retain the current scene during hot reload, or restart it.
- `repaintBoundary` — whether the GraphX surface is its own Flutter repaint boundary.
- `maxDelta` — limits how much elapsed time one update is allowed to receive.
- `pointer` — enables pointer input from the Flutter surface.
- `hitTestBehavior` — claim the whole view or only interactive GraphX content.
- `keyboard` — capture raw keyboard input.
- `autofocus` — request Flutter focus when the surface attaches.

Most scenes should start with the defaults.

### Why `maxDelta` exists

Frame time is not always well behaved.

A debugger can pause the app. A browser tab can disappear into the background. A device can stall for a moment. When the next frame finally arrives, the real elapsed time may be much larger than the roughly 16 ms you expected at 60 fps.

If motion code blindly consumes that entire delay at once, a simple update such as:

```dart
ball.x += velocityX * delta;
```

can suddenly move the ball a huge distance. Physics and numerical simulations can suffer even more: collisions can be skipped, springs can overshoot badly, and integration becomes less stable as the timestep grows.

`maxDelta` puts a ceiling on the `delta` GraphX delivers to the update cycle:

```dart
const GraphXConfig(
  maxDelta: 1 / 15,
);
```

The default `1 / 15` means a single update receives at most about 66.7 ms, even if considerably more real time passed between frames.

This is a safety guard, not a target frame rate. GraphX is not trying to run at 15 fps.

It is also not the same thing as a fixed-timestep simulation. When GraphX clamps a very late frame, the excess time is not automatically replayed through several hidden updates. For ordinary visual motion that guardrail is often exactly what you want. [Fixed-step simulation](#fixed-step-simulation) covers accumulated time, fixed simulation steps, and optional render interpolation as a separate technique.

During development, the two forms also make different hot-reload choices: class-based `GraphXView` retains its scene by default, while `GraphXView.scene(...)` restarts its callback scene. Those defaults match the usual reason you picked each form in the first place.

This only affects hot reload in development/debug sessions. It does not change normal runtime or release behavior.

## Let the scene earn its class

You do not need to design the final architecture before drawing the first circle.

Start with the callback when it makes the idea obvious. Keep it when the scene remains pleasantly small. Move to a root class when state, lifecycle overrides, or named behavior make the scene easier to understand that way.

The scene model stays the same either way, which means learning the simple form is not throwaway knowledge. It is the same GraphX, just with a different place to organize the work.
