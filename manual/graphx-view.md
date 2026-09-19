# GraphXView

`GraphXView` is the treaty line between two very different systems.

Flutter gives it a rectangle in the widget tree. Inside that rectangle, GraphX owns a retained stage.

## Flutter decides the viewport

This is enough to create a scene:

```dart
GraphXView.scene((root) {
  final dot = root.addChild(GShape());
  dot.graphics
      .beginFill(Colors.orange)
      .drawCircle(0, 0, 12)
      .endFill();

  dot.setPosition(
    root.stage.width * 0.5,
    root.stage.height * 0.5,
  );
});
```

Flutter layout determines the final `GraphXView` size. GraphX turns that size into `stage.width` / `stage.height` and renders the retained scene inside it.

No GraphX child participates in Flutter's `Row`, `Column`, constraints, or intrinsic sizing. That boundary is the same one introduced in [Scenes are not layouts](#scenes-are-not-layouts).

## Rebuilding the widget does not mean rebuilding the scene

This is one of the most important integration details.

A Flutter parent may rebuild because app state changed:

```dart
GraphXView(
  root: GameScene.new,
  value: gameState,
);
```

That does not imply that `GameScene`, its children, textures, transforms, or interaction state should be thrown away.

GraphX keeps the scene alive and synchronizes the new Flutter-side value into the existing stage.

A root can listen for that bridge while attached:

```dart
class GameScene extends GRoot {
  GSignalSubscription? syncSubscription;

  @override
  void attached() {
    syncSubscription = stage.signals.onFlutterSync.add((sync) {
      final state = sync.data<GameState>();
      applyState(state);
    });
  }

  void applyState(GameState state) {
    // Update retained nodes here.
  }

  @override
  void detached() {
    syncSubscription?.cancel();
    syncSubscription = null;
  }
}
```

`GFlutterSync` also carries the current Flutter `BuildContext` for integration code that genuinely needs it.

The mental model is simple:

```text
Flutter rebuilds widget configuration
          ↓
GraphXView synchronizes new host data
          ↓
existing retained GraphX scene updates
```

## `controller` lets Flutter call into the scene

Sometimes Flutter does not want to *push state on every rebuild*. It wants to issue a command:

```dart
final controller = GraphXController<GameScene>();
```

Attach it to the view:

```dart
GraphXView(
  root: GameScene.new,
  controller: controller,
);
```

Then Flutter-side code can reach the attached root:

```dart
controller.root.openInventory();
```

Use `controller.rootOrNull` or `controller.isAttached` when that code can run before/after the view lifecycle.

`value` is good for synchronized host data. `controller` is good for explicit imperative interaction with a retained scene. They solve different problems.

## `GraphXConfig` controls the host boundary

The defaults are intentionally small:

```dart
const GraphXConfig(
  reloadMode: GraphXReloadMode.retain,
  repaintBoundary: true,
  maxDelta: 1 / 15,
  pointer: true,
  hitTestBehavior: GHitTestBehavior.opaque,
  keyboard: false,
  autofocus: false,
)
```

We have already met most of these in context. The two hit-testing modes are worth seeing together:

```dart
GHitTestBehavior.opaque
```

claims the complete GraphX viewport for pointer hit testing.

```dart
GHitTestBehavior.content
```

claims only positions that resolve to interactive GraphX content.

That second mode can be handy when a GraphX surface sits over ordinary Flutter UI and empty scene space should let pointer interaction continue to whatever is behind it.

## Callback and class forms choose different hot-reload defaults

```dart
GraphXView.scene(...)
```

defaults to restarting its callback scene on Flutter hot reload.

```dart
GraphXView(root: GameScene.new)
```

defaults to retaining the current scene and calling its reassemble path.

As noted earlier, this concerns development hot reload only. It is not a release/runtime scene policy.

## One widget can contain a surprisingly independent world

A normal Flutter app can therefore look like this:

```dart
Column(
  children: [
    const AppToolbar(),
    Expanded(
      child: GraphXView(
        root: EditorScene.new,
        value: editorState,
      ),
    ),
    const StatusBar(),
  ],
)
```

Flutter owns the application layout around the scene. GraphX owns the transformed, interactive visual world inside that one rectangle.

That separation is the reason both systems can stay good at what they were designed to do.
