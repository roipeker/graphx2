# Gestures

Raw pointer events tell you what the pointer is doing.

A gesture adds a little interpretation on top: did that press move far enough to become a drag? Did it stay still long enough to count as a long press? Should an object simply follow the pointer until we tell it to stop?

GraphX keeps those choices separate so you can use the smallest tool that fits the interaction.

## Start with the simplest thing

If all you need is a tap, use the tap signal we already know:

```dart
button.pointer.onTap.add((event) {
  button.rotation += 0.1;
});
```

There is no reason to build a larger gesture object around a basic tap.

Likewise, if you genuinely need raw press/move/release information, stay with the pointer signals from [Pointer input](#pointer-input).

Gestures become useful when you want GraphX to interpret the sequence for you.

## Direct dragging: `startDrag()`

Sometimes there is no recognition problem at all. You press an object and want it to follow the pointer immediately.

GraphX has a direct node behavior for that:

```dart
box.pointer.onDown.add((event) {
  box.startDrag();
});

box.pointer.onUp.add((event) {
  box.stopDrag();
});

box.pointer.onCancel.add((event) {
  box.stopDrag();
});
```

When `startDrag()` is called from a node pointer callback, GraphX automatically uses the pointer currently being dispatched.

This is intentionally close to the direct `startDrag()` style familiar from older display-list APIs: tell the node to follow a pointer, then tell it when to stop.

That also means `startDrag()` is **behavior, not gesture recognition**. It does not wait to decide whether the user intended a drag. Once started, the node follows the pointer until `stopDrag()` is called, the pointer is cancelled, or the node leaves the stage.

## Preserve the grab point or lock to the center

By default, GraphX preserves where the user grabbed the node.

If the pointer went down 12 pixels from the node's origin, that offset stays while dragging instead of making the node jump under the cursor.

When you want the registration point to snap directly to the pointer instead:

```dart
box.startDrag(lockCenter: true);
```

The name comes from the familiar drag convention, but technically it locks the node's registration point to the pointer. If you aligned the pivot/registration point to the visual center, it behaves like a centered drag.

## Constrain a direct drag

You can also constrain the node's registration point in its parent coordinate space:

```dart
final dragBounds = GBounds(0, 0, 400, 240);

box.startDrag(
  bounds: dragBounds,
);
```

`GBounds` stores its two extrema as `x1, y1, x2, y2`, so the example above describes the region from `(0, 0)` to `(400, 240)`.

That is useful for sliders, draggable panels, game pieces, editor handles, and anything else that must stay inside a region.

The bounds apply to the node's `x` / `y` registration point, not automatically to the complete visual bounds of the object. If the whole artwork must remain inside a region, account for its size/pivot when choosing the drag bounds.

## Recognition: `GDrag`

A different problem is deciding whether a press should become a drag at all.

A user may move a few pixels accidentally while trying to tap. Starting a drag on the first tiny movement can make controls feel nervous.

`GDrag` waits until movement crosses a stage-space slop threshold:

```dart
final drag = GDrag(card);

drag.onStart.add((event) {
  card.alpha = 0.8;
});

drag.onUpdate.add((event) {
  card.x += event.deltaX;
  card.y += event.deltaY;
});

drag.onEnd.add((event) {
  card.alpha = 1.0;
});
```

The default slop is small enough to ignore normal hand jitter before recognizing the drag.

You can choose a different threshold when the interaction needs it:

```dart
final drag = GDrag(card, slop: 12);
```

`GDrag` does not move the node for you. It recognizes a drag and reports the motion; what the scene does with that motion is your decision.

That is the main difference from `startDrag()`:

- `startDrag()` — immediately makes a node follow a pointer;
- `GDrag` — recognizes drag intent and emits gesture events.

## Drag coordinates

`GDragEvent` reports stage-space positions and movement:

```dart
event.startX
event.startY
event.x
event.y
event.deltaX
event.deltaY
event.totalDeltaX
event.totalDeltaY
```

`deltaX` / `deltaY` are the movement since the previous drag update. `totalDeltaX` / `totalDeltaY` are the movement from where the drag began.

The event also keeps the underlying routed pointer event as `source` when you need device kind, pointer id, or coordinate conversion.

One performance detail is worth knowing: `GDragEvent` objects are reused while dispatching. If you need a value after the callback returns, copy the numbers you care about rather than storing the event object itself.

## Long press

A long press combines time with movement tolerance:

```dart
final longPress = GLongPress(card);

longPress.onLongPress.add((event) {
  card.scale = 1.1;
});
```

By default, GraphX waits 500 ms. If the pointer moves too far before the delay finishes, recognition is cancelled.

Both values are configurable:

```dart
final longPress = GLongPress(
  card,
  delay: const Duration(milliseconds: 700),
  slop: 10,
);
```

That makes it useful for context actions, selection, inspect modes, or controls where a normal tap and a deliberate hold mean different things.

## Recognizers attach to nodes

`GDrag` and `GLongPress` listen to the node's already-routed pointer sequence.

They do not create another hit-testing system. Visibility, activity, `pointer.enabled`, composite targeting, transforms, and automatic press capture still come from the same node pointer model we have already learned.

The recognizers also dispose themselves when their node is disposed. You can dispose them earlier when you intentionally want to stop recognizing the gesture before the node goes away.

## A Flutter analogy

If you use Flutter, the broad idea is similar to the difference between raw `PointerEvent` handling and a `GestureDetector`: raw events tell you what happened, while a recognizer decides what that sequence *means*.

GraphX keeps that interpretation attached to retained scene nodes rather than widgets.

The direct `startDrag()` helper is a little different from Flutter's usual gesture APIs because it is intentionally imperative: **make this object follow that pointer now**.

That kind of direct behavior is often useful in editors, games, diagrams, and playful interfaces where scene objects are already long-lived mutable things.

## Choose the smallest layer

A useful rule of thumb:

- use `onTap` for a tap;
- use raw pointer signals when you genuinely need raw pointer state;
- use `startDrag()` when the object should simply follow the pointer;
- use `GDrag` when you need drag recognition and deltas;
- use `GLongPress` when time + movement tolerance define the gesture.

There is no benefit in turning every interaction into a recognizer. GraphX keeps the lower levels available precisely so simple interactions can stay simple.

Next we will move away from pointers for a moment and look at keyboard input—another place where a GraphX scene needs to cooperate cleanly with Flutter and the host platform.
