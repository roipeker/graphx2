# Keyboard

A keyboard is not a special GraphX device. Flutter already knows how to talk to the platform keyboard; GraphX keeps the useful state and exposes it to the retained scene.

## Flutter supplies the key identity

`GraphXView` receives Flutter `KeyDownEvent`, `KeyRepeatEvent`, and `KeyUpEvent` through its focus host, then converts them to `GKeyEvent`.

GraphX deliberately reuses Flutter key identities:

```dart
GKey == LogicalKeyboardKey
```

`GKey` is a typedef, not another key-code table to memorize.

Each `GKeyEvent` keeps both logical and physical identity:

```dart
keyboard.onDown.add((event) {
  print(event.logicalKey);
  print(event.physicalKey);
  print(event.character);
});
```

Use the logical key when you care about meaning — `A`, Escape, Arrow Left. Use the physical key when the physical keyboard position matters regardless of layout.

## Raw keyboard capture belongs to `GraphXView`

A GraphX surface only receives keyboard events while its Flutter focus host owns keyboard focus.

For a scene that wants raw keyboard input even without focusable GraphX controls, enable keyboard capture in the view config:

```dart
GraphXView(
  root: GameScene.new,
  config: const GraphXConfig(
    keyboard: true,
    autofocus: true,
  ),
);
```

`keyboard: true` means raw key events are captured while the GraphX view has Flutter focus. `autofocus: true` asks Flutter for that focus when the view attaches.

This does not install a global keyboard hook. If another Flutter control owns focus, that control still owns the keyboard.

## The keyboard manager keeps held state

Once attached, a root has a shortcut to the stage keyboard manager:

```dart
final keyboard = root.keyboard;
```

The full path is the same object:

```dart
final keyboard = root.stage.input.keyboard;
```

Signals cover the event stream:

```dart
keyboard.onDown.add((event) {
  print('down: ${event.logicalKey}');
});

keyboard.onRepeat.add((event) {
  print('repeat: ${event.logicalKey}');
});

keyboard.onUp.add((event) {
  print('up: ${event.logicalKey}');
});
```

`onDown` represents the initial press. Repeated platform key events go to `onRepeat` instead of pretending the key was freshly pressed again.

## Games usually read state once per frame

For movement, the question is often not *which event just fired?* but *is this key currently held?*

```dart
class GameScene extends GRoot {
  late final GNode player;

  @override
  void attached() {
    player = addChild(GNode());
    updatesEnabled = true;
  }

  @override
  void update(double delta) {
    final speed = 220.0;

    if (keyboard.isDown(GKey.arrowLeft)) {
      player.x -= speed * delta;
    }

    if (keyboard.isDown(GKey.arrowRight)) {
      player.x += speed * delta;
    }
  }
}
```

The same manager exposes one-frame edges:

```dart
if (keyboard.wasPressed(GKey.space)) {
  jump();
}

if (keyboard.wasReleased(GKey.space)) {
  stopChargingJump();
}
```

That distinction is common in game loops: `isDown()` describes sustained state; `wasPressed()` / `wasReleased()` describe the transition associated with the current GraphX frame.

## Modifier keys are already grouped

You can inspect exact keys, or use the convenience modifiers:

```dart
if (keyboard.meta && keyboard.wasPressed(GKey.keyS)) {
  save();
}
```

The manager exposes `shift`, `control`, `alt`, and `meta` by checking the corresponding left/right logical keys.

## Losing Flutter focus clears stale keys

Imagine holding Arrow Right and switching to another application before Flutter receives the key-up event.

GraphX clears held keyboard state when the GraphX focus host loses Flutter focus, and also when stage input is disabled. `keyboard.onReset` exists for code that needs to react to that reset explicitly.

That prevents an old held key from remaining stuck forever inside the retained scene.

## Raw keys and semantic actions solve different problems

A platform game may genuinely care about `GKey.arrowLeft`.

A menu button usually cares about something broader: **activate this control**, whether that came from Enter, Space, a TV remote Select button, a gamepad A button, or accessibility semantics.

That second problem belongs to GraphX focus and actions, not raw keyboard state. The next chapter builds that layer on top of the same Flutter focus host.
