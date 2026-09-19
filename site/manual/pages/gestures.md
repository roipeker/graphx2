# Gestures

A pointer moved. Was that a drag, or did somebody's finger just wobble three pixels while tapping?

That is the point where raw input stops being enough. A gesture assigns meaning to a pointer sequence.

GraphX keeps the layers separate: use raw pointer signals when you need raw input, direct behavior when you already know what should happen, and a recognizer when intent needs to be decided.

## A tap does not need a gesture object

For the common tap case, GraphX already does the small amount of recognition required:

```dart
button.pointer.onTap.add((event) {
  button.rotation += 0.1;
});
```

Likewise, code that genuinely cares about down/move/up can stay on `node.pointer`. A recognizer is useful only when it adds a decision you otherwise have to implement yourself.

## `startDrag()` means “follow this pointer now”

There is no threshold or debate here:

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

Called from a node pointer callback, `startDrag()` automatically uses the currently dispatched pointer.

This is deliberately imperative and close to the old display-list/Flash idea: **make this object follow the pointer until I stop it.** It is behavior, not gesture recognition.

By default the original grab offset is preserved, so an object does not jump when you press away from its registration point. To pin the registration point directly under the pointer:

```dart
box.startDrag(lockCenter: true);
```

And to constrain that registration point in parent space:

```dart
final dragBounds = GBounds(0, 0, 400, 240);

box.startDrag(
  bounds: dragBounds,
);
```

`GBounds` stores `x1, y1, x2, y2`, so this is the region from `(0, 0)` to `(400, 240)`. The bounds constrain the node registration point, not its entire visual footprint.

## `GDrag` waits for intent

A drag recognizer solves the opposite problem: *do not call this a drag yet.*

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

`GDrag` watches the already-routed press sequence and waits until movement crosses its stage-space slop threshold. Tiny accidental movement can still become a tap; deliberate movement becomes a drag.

The threshold is configurable:

```dart
final drag = GDrag(card, slop: 12);
```

Unlike `startDrag()`, the recognizer does not move anything. It reports that a drag began and gives the scene the motion data to interpret however it wants.

`GDragEvent` exposes the start, current position, per-update delta, and total delta:

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

Those values are in stage space. The underlying routed pointer event remains available as `event.source` when you need pointer id, device kind, or local/world conversion.

`GDragEvent` is reused during dispatch. Copy values you need to retain after the callback rather than holding onto the event object.

## Long press = time plus restraint

A long press has two conditions: enough time must pass, and the pointer must not wander too far first.

```dart
final longPress = GLongPress(card);

longPress.onLongPress.add((event) {
  card.scale = 1.1;
});
```

The default delay is 500 ms. Both delay and movement slop can be changed:

```dart
final longPress = GLongPress(
  card,
  delay: const Duration(milliseconds: 700),
  slop: 10,
);
```

Move beyond that tolerance before the delay finishes and the long press is rejected.

## Flutter does the platform input; GraphX recognizes inside the scene

Flutter has a similar conceptual split between low-level `PointerEvent`s and higher-level gesture recognition such as `GestureDetector`.

GraphX receives Flutter's pointer stream but performs its node hit testing, capture, and these recognizers against the retained GraphX hierarchy. There is no second widget subtree for every draggable scene object.

The direct `startDrag()` helper is intentionally more imperative than Flutter's usual widget gesture API because GraphX nodes are already long-lived mutable scene objects.

A compact way to choose the layer is:

- `onTap` when a tap is enough;
- raw node/stage pointer signals when raw state matters;
- `startDrag()` when the object should follow immediately;
- `GDrag` when movement must cross a threshold first;
- `GLongPress` when time and movement tolerance define the action.

The next interaction layer is keyboard input, where Flutter focus and the GraphX scene have a different boundary to negotiate.
