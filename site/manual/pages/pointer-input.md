# Pointer input

Flutter gets the pointer to the GraphX surface. GraphX decides which retained object it belongs to.

That division is useful to understand because GraphX is not replacing Flutter's platform input stack. It takes Flutter pointer events and routes them through the scene you already built.

## From Flutter `PointerEvent` to a GraphX node

At the `GraphXView` boundary, Flutter supplies events such as `PointerDownEvent`, `PointerMoveEvent`, `PointerUpEvent`, `PointerCancelEvent`, `PointerHoverEvent`, and `PointerScrollEvent`.

Trackpad pan/zoom arrives through Flutter's `PointerPanZoomStartEvent`, `PointerPanZoomUpdateEvent`, and `PointerPanZoomEndEvent` too.

GraphX converts the Flutter position into coordinates local to the GraphX surface and carries across the information that matters: pointer id, device kind, movement delta, buttons, scrolling, and timestamp.

From there, GraphX takes over the scene-specific work:

```text
Flutter PointerEvent
        ↓
GraphXView surface coordinates
        ↓
scene hit test
        ↓
GNodePointerEvent
        ↓
target node → parent → parent …
```

So Flutter knows that a touch, mouse, stylus, or trackpad event happened. GraphX knows which transformed node in your retained hierarchy should receive it.

## Tap the object, not the canvas

For the common case, interaction lives directly on the node:

```dart
card.pointer.onTap.add((event) {
  card.rotation += 0.15;
});
```

`onTap` is synthesized from the press sequence with a small movement tolerance. You do not need to manually compare down/up positions for an ordinary tap.

The same pointer surface exposes the lower-level routed signals when you need them:

```dart
card.pointer.onDown.add((event) {
  card.scale = 0.95;
});

card.pointer.onUp.add((event) {
  card.scale = 1.0;
});
```

The main signals are `onDown`, `onMove`, `onUp`, `onCancel`, `onScroll`, and `onTap`. Hover adds `onEnter` and `onExit`, which we will use in the next chapter.

GraphX also keeps pointer hit testing demand-driven: adding pointer interest to a node is what makes that branch relevant to routed pointer work. A scene full of decorative nodes does not need to behave like a scene full of controls.

## Two pointer surfaces answer different questions

`node.pointer` asks:

> Did the pointer interact with this object or its routed hierarchy?

`stage.pointer` asks:

> What is the pointer doing over the GraphX surface at all?

The stage-wide manager exposes state independently of a particular hit target:

```dart
final pointer = root.stage.pointer;

print(pointer.x);
print(pointer.y);
print(pointer.isDown);
```

That is a better fit for camera navigation, diagnostics, global cursor state, multitouch bookkeeping, or trackpad pan/zoom. Node pointer signals are the better fit when scene geometry should decide who receives the event.

## Coordinates arrive in stage space

A routed `GNodePointerEvent` keeps its `x` and `y` in GraphX stage-surface coordinates:

```dart
card.pointer.onDown.add((event) {
  print(event.x);
  print(event.y);
});
```

That common coordinate space is useful for things such as camera movement or comparing multiple objects.

But when the question is *where did this land inside the card?*, convert through the routed event:

```dart
card.pointer.onDown.add((event) {
  final local = event.localPosition(card);
  if (local == null) return;

  print(local.x);
  print(local.y);
});
```

Now `(0, 0)` is the card's own origin even if the card is rotated, scaled, nested under transformed parents, or viewed through a non-trivial interaction mapping.

This is the pointer-side version of [Coordinate spaces](#coordinate-spaces). `localPosition()` deliberately follows the same interaction-space mapping used by GraphX hit testing.

## The target survives bubbling

Imagine a button made from a background and an icon:

```text
button
└── icon
```

If the icon is hit, the event starts there and bubbles upward through the node hierarchy. A listener on the button can receive the same event:

```dart
button.pointer.onTap.add((event) {
  print(event.target);
});
```

`event.target` still points to the icon because that is what GraphX actually hit.

This lets a parent own behavior for a composite object without duplicating listeners on every child. In the next chapter we will also see `pointer.children = false`, which changes that relationship and makes the parent itself the target.

## A press is a sequence, not one event

A pointer press can travel through several states:

```dart
card.pointer.onDown.add((event) {
  // Press began on this target.
});

card.pointer.onMove.add((event) {
  // That pointer moved.
});

card.pointer.onUp.add((event) {
  // It ended normally.
});

card.pointer.onCancel.add((event) {
  // The host cancelled the sequence.
});
```

GraphX remembers which target received the down event, so move/up do not suddenly jump to another object just because the pointer leaves the original geometry. That capture behavior is important enough to examine properly in [Hover and capture](#hover-and-capture).

## Mouse, touch, stylus, trackpad

The device distinction comes from Flutter's `PointerDeviceKind`; GraphX converts it to `GPointerDeviceKind` rather than inventing its own platform detector.

```dart
card.pointer.onDown.add((event) {
  print(event.kind);
  print(event.pointer);
});
```

The kind can be mouse, touch, stylus, inverted stylus, trackpad, or unknown. The pointer id distinguishes simultaneous contacts, so two touches can remain two independent sequences.

Scrolling also stays explicit, and trackpad pan/zoom has dedicated stage signals rather than being disguised as mouse movement.

The result is one GraphX pointer model across Flutter's supported input devices, while still preserving the device information when your interaction actually cares about it.

## Trackpad pan, zoom, and rotation have their own signals

Flutter reports trackpad gestures with `PointerPanZoomStartEvent`, `PointerPanZoomUpdateEvent`, and `PointerPanZoomEndEvent`. GraphX keeps that richer gesture intact on the stage pointer manager:

```dart
final pointer = root.stage.pointer;

pointer.onPanZoomStart.add((gesture) {
  print('gesture started at ${gesture.x}, ${gesture.y}');
});

pointer.onPanZoomEnd.add((gesture) {
  print('gesture ended');
});
```

`GPointerPanZoomState` carries translation, scale, and rotation for the same gesture. `panX` / `panY`, `scale`, and `rotation` are cumulative from the gesture start, which makes them convenient for applying an absolute transform from a saved baseline:

```dart
final world = root.addChild(GNode());
final pointer = root.stage.pointer;

var startX = 0.0;
var startY = 0.0;
var startScale = 1.0;
var startRotation = 0.0;

pointer.onPanZoomStart.add((gesture) {
  startX = world.x;
  startY = world.y;
  startScale = world.scale;
  startRotation = world.rotation;
});

pointer.onPanZoomUpdate.add((gesture) {
  world.setPosition(
    startX + gesture.panX,
    startY + gesture.panY,
  );
  world.scale = startScale * gesture.scale;
  world.rotation = startRotation + gesture.rotation;
});
```

That is enough for a small map, editor surface, or visual playground: two-finger pan moves the retained world, pinch scales it, and trackpad rotation rotates it.

The transform above uses `world`'s own pivot as the zoom/rotation origin. A camera that keeps the exact point under the fingers stationary needs one more coordinate-space step; we will handle that when render views/cameras get their own chapter.

The state also exposes `panDeltaX/Y`, `scaleDelta`, and `rotationDelta`. Those are accumulated for the current GraphX frame and reset at frame teardown. They are useful when consuming input once per frame; the cumulative gesture values above are clearer when mutating directly from each `onPanZoomUpdate` signal.

The pan/zoom state object itself is reused. Copy values rather than storing the object if they must survive beyond the callback.

## Hit testing follows the scene

GraphX resolves node input against the retained hierarchy, not against a separate rectangle tree.

Move a node, rotate it, scale it, or nest it under transformed parents and its interaction follows those transforms. Hide or deactivate a branch and it leaves pointer routing with the rest of that branch.

Sometimes the artwork and the best interaction geometry are different. That is where hover, capture, composite targeting, custom hit areas, and cursors come in next.
