# Focus

Pointer input can ask *what is under the pointer?* Keyboard, TV remote, gamepad, and accessibility input need a different answer:

> Which scene object is active when there is no pointer location at all?

That is focus.

## Focus uses the GraphX scene tree

GraphX does not create a second hidden focus hierarchy beside the nodes.

Make an existing node focusable:

```dart
button.focusable = true;
```

Then it can become the stage's logical focus target:

```dart
button.requestFocus();

print(button.hasFocus);
print(stage.focus.focusedNode);
```

`stage.focus` is the lazy stage-scoped focus manager introduced in [Lifecycle and the stage](#lifecycle-and-the-stage).

A parent can ask whether focus is anywhere in its subtree:

```dart
if (panel.hasFocusWithin) {
  // A descendant currently owns focus.
}
```

## Focus changes are node signals

A retained control can react to focus without becoming a Flutter widget:

```dart
button.onFocusChanged.add((focused) {
  button.scale = focused ? 1.08 : 1.0;
});
```

`onFocusWithinChanged` does the same for a node and its descendants.

By default, pressing directly on a focusable GraphX node also requests focus. Advanced controls can change that through:

```dart
button.focus.focusOnPointer = false;
```

## Actions describe intent, not hardware

A focused node can listen for semantic actions:

```dart
button.onAction.add((event) {
  if (event.action != GActions.activate) return;

  activateButton();
  event.handle();
});
```

`activate` is deliberately not called `enterPressed` or `gamepadA`.

The default keyboard mappings translate familiar keys into actions:

```text
Tab / Shift+Tab       → focusNext / focusPrevious
Arrow keys            → focusLeft / focusRight / focusUp / focusDown
Enter / Space / Select → activate
Escape / Back         → back
```

The same action API can also be driven by a remote, gamepad, accessibility adapter, or synthetic code:

```dart
stage.actions.dispatch(
  GActions.activate,
  source: GActionSource.gamepad,
);
```

That lets scene behavior depend on intent while input adapters decide which device gesture means that intent.

## Actions bubble from the focused node

Action routing follows the retained hierarchy too.

If a focused child does not handle an action, its parent gets a chance:

```dart
child.onAction.add((event) {
  // inspect first
});

panel.onAction.add((event) {
  if (event.action == GActions.back) {
    closePanel();
    event.handle();
  }
});
```

Once `event.handle()` is called, routing stops.

If nobody in the focused path handles a navigation action, GraphX can apply its default focus traversal afterwards.

## Tab follows scene order

Sequential traversal walks focusable nodes in retained scene order:

```text
root
├── buttonA
├── group
│   └── buttonB
└── buttonC
```

With all three buttons focusable, forward traversal visits `buttonA → buttonB → buttonC`.

A node can stay programmatically focusable while being skipped by traversal:

```dart
buttonB.focus.skipTraversal = true;
```

`buttonB.requestFocus()` can still focus it explicitly.

## Arrow navigation uses scene geometry

Directional focus is not just another copy of tree order.

GraphX uses the retained world geometry of focusable nodes to find candidates left, right, up, or down. That matters for spatial UIs, TV screens, game menus, editors, and grids where visual placement is the navigation model.

When automatic geometry is not the rule you want, explicit neighbors win:

```dart
center.focus.right = detailsButton;
center.focus.down = playButton;
```

The same focus model therefore supports both automatic spatial traversal and authored navigation graphs.

## The GraphX scene should not trap Flutter focus by accident

The default focus edge behavior is:

```dart
stage.focus.edgeBehavior = GFocusEdgeBehavior.parent;
```

At the edge of GraphX traversal, focus can continue into the surrounding Flutter app.

Other policies are available when the scene should behave like a self-contained focus domain:

```dart
stage.focus.edgeBehavior = GFocusEdgeBehavior.stop;
```

or:

```dart
stage.focus.edgeBehavior = GFocusEdgeBehavior.wrap;
```

That boundary is important for embedding GraphX inside a normal Flutter application. A scene can own rich internal focus without hijacking the whole app's traversal model.

## Hiding or removing a focused node repairs focus

Focus eligibility follows the same scene state we already learned.

A node cannot remain the logical target if it becomes hidden, inactive, non-focusable, detached, or disposed. GraphX clears/repairs focus when that happens.

Reparenting inside the same stage is different: just as with lifecycle, the node did not leave the runtime, so its focus can be preserved while `hasFocusWithin` is updated along the old and new ancestor paths.

## Raw keyboard capture is optional

A focusable GraphX scene can participate in Flutter focus traversal even if `GraphXConfig.keyboard` is false.

That configuration flag controls **raw keyboard capture**. Logical GraphX focus/actions are a higher-level feature: when the GraphX focus host owns Flutter focus, key events can be translated to actions such as `activate`, `back`, and directional navigation.

Use raw keyboard state for things like game movement and editor shortcuts. Use focus/actions for controls whose behavior should survive changes in input device.

## Custom shortcuts can feed the same action layer

The stage action input can bind an exact logical-key shortcut to a semantic action:

```dart
const saveAction = GAction('save');

stage.actions.bind(
  const GShortcut(
    GKey.keyS,
    meta: true,
  ),
  saveAction,
);
```

Then focused-node action handlers can respond to `saveAction` without being coupled to the shortcut that produced it.

That separation becomes more valuable as GraphX moves beyond desktop keyboard/mouse scenes into TV, gamepad, portal, and accessibility-heavy interfaces.
