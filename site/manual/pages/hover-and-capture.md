# Hover and capture

A tap is simple because it starts and ends quickly.

Hovering, dragging, and composite controls make pointer behavior a little more interesting. GraphX keeps those cases tied to the same scene hierarchy instead of introducing a separate interaction tree.

## Hover follows the scene

For pointer devices that support hover, nodes can listen for enter and exit:

```dart
card.pointer.onEnter.add((event) {
  card.scale = 1.05;
});

card.pointer.onExit.add((event) {
  card.scale = 1.0;
});
```

`onEnter` and `onExit` are based on the pointer path through the scene hierarchy.

One useful retained-scene detail is that hover can change even when the mouse does not move.

If a node moves underneath a stationary pointer, GraphX can reconcile the hover target from the new scene geometry. You do not have to wait for another physical mouse event before the scene notices that the pointer is now over something different.

That matters for animated menus, moving controls, editors, and other scenes where the objects themselves move as much as the pointer does.

## Cursors belong to scene objects too

A node can request a cursor while it or its targeted descendants are hovered:

```dart
card.pointer.cursor = GCursor.click;
```

Common built-in cursors include:

```dart
GCursor.basic
GCursor.click
GCursor.text
GCursor.move
GCursor.grab
GCursor.grabbing
GCursor.resizeH
GCursor.resizeV
GCursor.hidden
```

A null cursor inherits from the nearest ancestor that has one, eventually falling back to the stage pointer cursor.

That means a whole interactive branch can share a cursor without every small child setting it individually.

Cursor-only nodes can also participate in pointer hit testing; you do not need to add a dummy pointer listener just to make the cursor work.

## Press capture is automatic

Suppose the user presses a slider thumb and then moves the pointer outside the thumb's visible bounds before releasing.

If move/up events suddenly switched to whatever happened to be under the pointer, the slider would be difficult to use.

GraphX solves that automatically: **the node targeted by pointer down owns that pointer until up or cancel.**

```dart
thumb.pointer.onDown.add((event) {
  thumb.alpha = 0.8;
});

thumb.pointer.onMove.add((event) {
  // Still receives the active press movement.
});

thumb.pointer.onUp.add((event) {
  thumb.alpha = 1.0;
});
```

The pointer can leave the thumb and the active press sequence still goes back to the original target.

Hover is separate. The hover target continues to follow actual geometry while the press target stays captured.

That split is useful: a drag can remain stable without pretending the pointer is still visually over the pressed object.

## Composite controls

A visual control is often made from several nodes:

```text
button
├── background
├── icon
└── label
```

By default, descendants can become independent pointer targets. That is useful when the pieces really are independently interactive.

Sometimes they are only visual pieces of one logical control.

Set:

```dart
button.pointer.children = false;
```

Now descendant visual geometry can still contribute to the hit, but `button` becomes the target instead of whichever child happened to be underneath the pointer.

This is especially handy for buttons, cards, list items, draggable groups, and other composite objects where the interaction belongs to the whole thing.

It also keeps event handling simpler:

```dart
button.pointer.onTap.add((event) {
  // event.target is button for the composite hit.
});
```

## Disable a whole pointer branch

We mentioned this earlier in [Visibility and activity](#visibility-and-activity):

```dart
panel.pointer.enabled = false;
```

This disables pointer routing for the node and its complete subtree without changing what gets rendered.

It is different from `visible = false`, which also removes the branch from rendering, and different from `pointer.children = false`, which keeps the subtree hittable but collapses targeting onto the parent.

Those three controls solve different problems:

- `visible = false` — do not render or interact with the branch;
- `pointer.enabled = false` — render it, but skip pointer interaction for the branch;
- `pointer.children = false` — let descendants contribute to the hit, but target the parent as one composite control.

## Make the hit area friendlier than the artwork

Visual geometry is not always good interaction geometry.

A tiny icon may need a larger touch target. A thin path may need a wider selectable corridor. A transparent control may need a hit shape even though it draws almost nothing.

GraphX lets pointer geometry be overridden without changing rendering or canonical bounds:

```dart
icon.hitArea = GHitArea.rect(
  -12,
  -12,
  48,
  48,
);
```

The icon can remain visually 24 × 24 while the pointer target is 48 × 48.

Other built-in hit areas include circles and Dart `Path` geometry:

```dart
node.hitArea = GHitArea.circle(0, 0, 30);
node.hitArea = GHitArea.path(path);
```

For a line or curve, a filled path may not describe the interaction you want. `pathStroke()` creates a selectable corridor around the path instead:

```dart
node.hitArea = GHitArea.pathStroke(path, 18);
```

The width is the complete interaction width, independent of the visible stroke width.

That is useful for editors and diagrams where a 1 px line should still be easy to select.

## Graphics can provide a stroke hit area

If the path already lives inside `GGraphics`, GraphX can build the selectable corridor from the retained stroked geometry:

```dart
shape.hitArea = shape.graphics.strokeHitArea(18);
```

The hit area tracks the retained graphics geometry and lazily refreshes its internal sampled representation when that geometry changes.

Again, the visual stroke can stay thin. Interaction width is a separate decision.

## Hit areas stay local

Custom hit areas use the node's local coordinate space.

That means you define them next to the object itself:

```dart
card.hitArea = GHitArea.rect(0, 0, 180, 80);
```

Then normal GraphX transforms take care of the rest. Move, rotate, scale, or nest the card and the hit area follows the node through the scene hierarchy.

This is the same local-first idea used by drawing and bounds: define the object in its own space, then let the scene transform place it.

## When a custom hit area changes in place

Most built-in hit areas are immutable enough that replacing the value is straightforward.

If you implement a mutable custom `GHitArea` and change its geometry without assigning a new object, call:

```dart
node.invalidateHitArea();
```

That tells GraphX to reconcile hover against the changed interaction geometry, which matters when the mouse is stationary.

You usually do not need this for the normal `GHitArea.rect()`, `circle()`, or `path()` cases.

## From capture to gestures

Automatic press capture gives low-level interactions a stable event sequence, but dragging something usually involves more than forwarding move events.

GraphX also has higher-level gesture helpers and recognizers for those cases. The next chapter will look at the difference between raw pointer input, direct drag behavior, and gesture recognition so you can choose the smallest tool that fits the interaction.
