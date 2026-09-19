# Hover and capture

Press a slider thumb, drag outside it, then release.

A naïve hit tester loses the thumb as soon as the pointer leaves its pixels. GraphX does not: the node that received pointer down keeps that pointer until the sequence ends.

## The pressed node keeps the pointer

Capture is automatic for routed node presses.

```dart
thumb.pointer.onDown.add((event) {
  thumb.alpha = 0.8;
});

thumb.pointer.onMove.add((event) {
  // Still routed here after the pointer leaves the thumb.
});

thumb.pointer.onUp.add((event) {
  thumb.alpha = 1.0;
});
```

The original target continues receiving move/up until `up` or `cancel`. That gives drags, sliders, scrubbers, and handles a stable press sequence without a separate public `capture()` call.

Capture answers **who owns this press?** Hover answers a different question: **what is underneath the pointer right now?**

Those two answers are allowed to disagree.

## Hover follows geometry, even when the mouse stands still

```dart
card.pointer.onEnter.add((event) {
  card.scale = 1.05;
});

card.pointer.onExit.add((event) {
  card.scale = 1.0;
});
```

If the card moves underneath a stationary mouse, GraphX can reconcile the hover target from the changed scene geometry. It does not have to wait for Flutter to deliver another physical mouse move first.

That matters in a retained scene: menus animate, editor handles move, panels slide, camera transforms change. The world may move even when the pointer does not.

## A cursor can belong to a branch

```dart
card.pointer.cursor = GCursor.click;
```

GraphX includes the usual cursor intents—`basic`, `click`, `text`, `move`, `grab`, `grabbing`, horizontal/vertical resize, and `hidden`.

A null cursor inherits from the nearest ancestor cursor and eventually falls back to the stage pointer cursor. A parent can therefore establish the cursor for an entire interactive subtree.

A cursor is itself pointer interest, so you do not need to install a meaningless listener just to make a node discoverable for cursor changes.

## Sometimes the parent is the control

A button may be visually composed from several nodes:

```text
button
├── background
├── icon
└── label
```

If those children are only visual pieces, exposing each one as an independent target is noise. Collapse the interaction onto the parent:

```dart
button.pointer.children = false;
```

Descendant visual geometry can still contribute to the hit, but `button` becomes the target.

```dart
button.pointer.onTap.add((event) {
  // event.target is button.
});
```

This is particularly useful for cards, list rows, draggable groups, tool buttons, and other controls whose visual hierarchy is richer than their interaction model.

## Hiding and disabling are different operations

These three switches look similar until you ask what should remain:

- `visible = false` — skip rendering and pointer interaction for the branch;
- `pointer.enabled = false` — keep rendering, skip pointer interaction for the branch;
- `pointer.children = false` — keep descendant geometry, but treat the parent as one target.

So a disabled overlay can stay visible without intercepting input, while a complex button can remain a hierarchy without exposing every decorative child.

## The easiest target is not always the visible shape

A 16 px icon may need a 44 px touch target. A one-pixel editor line may need a much wider selectable corridor.

GraphX lets interaction geometry differ from rendered geometry:

```dart
icon.hitArea = GHitArea.rect(
  -14,
  -14,
  44,
  44,
);
```

That hit area is local to the node and does not change rendering or canonical visual bounds. Normal node transforms carry it through the scene.

Circles and Dart `Path` geometry are available too:

```dart
node.hitArea = GHitArea.circle(0, 0, 30);
node.hitArea = GHitArea.path(path);
```

For a thin path, a filled hit region is usually the wrong idea. A stroke corridor makes the line easier to select without making it visually thicker:

```dart
node.hitArea = GHitArea.pathStroke(path, 18);
```

If that path already lives in retained `GGraphics`, use its stroked geometry directly:

```dart
shape.hitArea = shape.graphics.strokeHitArea(18);
```

The interaction width and visual stroke width remain independent.

## Mutable hit geometry needs one signal

If you write a custom mutable `GHitArea` and mutate it in place, GraphX cannot know its geometry changed merely from object identity.

Tell it:

```dart
node.invalidateHitArea();
```

That lets stationary hover be reconciled immediately against the new interaction shape.

The normal built-in rectangle, circle, and copied path cases do not require this extra step.

Capture gives us a stable low-level press. The next question is when a sequence should *mean* something higher-level—particularly when movement becomes a drag. That is the job of [Gestures](#gestures).
