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
resizeHandle.pointer.onEnter.add((event) {
  resizeHandle.scale = 1.15;
});

resizeHandle.pointer.onExit.add((event) {
  resizeHandle.scale = 1.0;
});
```

If the handle moves underneath a stationary mouse because the selected object or camera moved, GraphX can reconcile the hover target from the changed scene geometry. It does not have to wait for Flutter to deliver another physical mouse move first.

That matters in a retained scene: menus animate, editor handles move, panels slide, camera transforms change. The world may move even when the pointer does not.

## A cursor can belong to a branch

```dart
resizeHandle.pointer.cursor = GCursor.resizeH;
```

GraphX includes the usual cursor intents—`basic`, `click`, `text`, `move`, `grab`, `grabbing`, horizontal/vertical resize, and `hidden`.

A null cursor inherits from the nearest ancestor cursor and eventually falls back to the stage pointer cursor. A parent can therefore establish the cursor for an entire interactive subtree.

A cursor is itself pointer interest, so you do not need to install a meaningless listener just to make a node discoverable for cursor changes.

## Sometimes the parent is the control

A diagram item may contain several independently-rendered pieces while still representing one selectable object:

```text
item
├── body
├── title
├── status
└── ports
```

If those descendants should contribute visible hit geometry but selection should belong to the item as a whole, collapse targeting onto the parent:

```dart
item.pointer.children = false;
```

Descendant geometry can still contribute to the hit, but `item` becomes the routed target.

```dart
item.pointer.onTap.add((event) {
  // event.target is item.
});
```

That keeps the render hierarchy expressive without forcing the interaction model to expose every decorative child as a separate control.

## Hiding and disabling are different operations

These three switches look similar until you ask what should remain:

- `visible = false` — skip rendering and pointer interaction for the branch;
- `pointer.enabled = false` — keep rendering, skip pointer interaction for the branch;
- `pointer.children = false` — keep descendant geometry, but treat the parent as one target.

So a disabled overlay can stay visible without intercepting input, while a composite scene object can remain a hierarchy without exposing every decorative child.

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

It can also extend **outside** the node's visual bounds. GraphX tests the custom interaction geometry directly; it does not first clamp the point to the node's rendered bounding box.

That is a meaningful difference from normal Flutter `RenderBox` hit testing. Flutter's box hit test first asks whether the pointer is inside the render box's laid-out `size` before testing the box or its children. `HitTestBehavior.translucent` can make otherwise empty space *inside that box* participate; it does not make the box larger. If a Flutter control needs a larger tap target, the common solution is therefore to make the laid-out widget larger too—padding, a `SizedBox`, constraints, or another hit-test-aware wrapper—even when the visible artwork stays small.

GraphX can keep those concerns separate:

```text
rendered artwork:  16 × 16
pointer hit area:  44 × 44
canonical bounds:   still 16 × 16
```

That separation is especially handy in a free-form scene because the hit-test math can describe exactly the interaction region you want, including space beyond the artwork. Ancestor clips still apply: a hit area cannot escape a branch that is explicitly clipped away.

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
