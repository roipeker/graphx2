# Pointer input

A scene becomes much more interesting once the things inside it can respond directly to you.

GraphX keeps pointer input attached to the scene model: the node you draw and move can also be the node that receives taps, presses, movement, and scrolling.

## Start with a tap

You have already seen the simplest version:

```dart
card.pointer.onTap.add((event) {
  card.rotation += 0.15;
});
```

`onTap` is a convenience signal synthesized from the underlying press sequence. GraphX allows a small amount of pointer movement before deciding that a press stopped being a tap.

For buttons, cards, icons, and small interactive objects, that is often all you need.

## Pointer signals live on the node

A node exposes its pointer behavior through `pointer`:

```dart
card.pointer.onDown.add((event) {
  card.scale = 0.95;
});

card.pointer.onUp.add((event) {
  card.scale = 1.0;
});
```

The main routed signals are:

- `onDown`
- `onMove`
- `onUp`
- `onCancel`
- `onScroll`
- `onTap`

Hover-specific `onEnter` and `onExit` are there too, but we will give hover and capture their own chapter.

The signal only exists when you ask for it, and GraphX tracks pointer interest through the scene rather than forcing every node into hit-testing work all the time.

## Stage coordinates versus local coordinates

The `x` and `y` on a `GNodePointerEvent` are the raw GraphX stage-surface coordinates for that pointer event:

```dart
card.pointer.onDown.add((event) {
  print(event.x);
  print(event.y);
});
```

Sometimes that is exactly what you want—for example, when controlling a camera or comparing two objects in a common stage space.

Often, though, the useful question is more local:

> Where did the pointer land inside this object?

Use `localPosition()` for that:

```dart
card.pointer.onDown.add((event) {
  final local = event.localPosition(card);
  if (local == null) return;

  print(local.x);
  print(local.y);
});
```

Now `(0, 0)` means the card's own local origin, regardless of where the card sits in the scene or how its parents are transformed.

This is related to the conversions from [Coordinate spaces](#coordinate-spaces), but pointer events use the same interaction-space mapping that GraphX used for hit testing. That becomes important later when render views or projected/custom spaces enter the picture.

## The event remembers the target

Every routed node event has a `target`:

```dart
card.pointer.onDown.add((event) {
  print(event.target);
});
```

That is the node GraphX actually hit.

This becomes useful once interaction bubbles through a hierarchy.

## Events bubble through parents

Suppose an icon lives inside a button:

```text
button
└── icon
```

If the icon is the pointer target, GraphX dispatches the routed event to the icon and then continues upward through its parents.

That means a parent can listen for interaction coming from its descendants:

```dart
button.pointer.onTap.add((event) {
  print(event.target);
});
```

If the icon was hit, `event.target` remains the icon even while the button's listener is running.

This is useful for composite scene objects because a parent can own behavior without every visual child needing to duplicate the same listener.

Later we will look at `pointer.children`, which can deliberately make a composite parent become the pointer target instead of its individual descendants.

## Down, move, up, and cancel belong together

For interactions more involved than a tap, it is useful to think in terms of a press sequence:

```dart
card.pointer.onDown.add((event) {
  // A pointer started pressing this object.
});

card.pointer.onMove.add((event) {
  // The active pointer moved.
});

card.pointer.onUp.add((event) {
  // The press finished normally.
});

card.pointer.onCancel.add((event) {
  // The platform cancelled the sequence.
});
```

GraphX keeps track of the pointer that started the press so movement and release can stay associated with the same interaction even when the pointer moves away from the original hit geometry.

That automatic press capture is important for drags and sliders, so we will examine it properly in the next chapter instead of hiding the behavior inside this introduction.

## More than a mouse

GraphX uses pointer events rather than mouse-only events because the same scene may run on desktop, mobile, tablet, web, or another pointer-capable device.

Each event includes a device `kind` and pointer id:

```dart
card.pointer.onDown.add((event) {
  print(event.kind);
  print(event.pointer);
});
```

The kind can distinguish mouse, touch, stylus, trackpad, and related inputs. The pointer id lets separate touches remain separate during multitouch interaction.

You do not need special touch code just to make a node tappable.

## Node input and stage input are different tools

`node.pointer` answers questions about interaction with a particular scene object.

`stage.pointer` is the stage-wide pointer manager:

```dart
final pointer = root.stage.pointer;

print(pointer.x);
print(pointer.y);
print(pointer.isDown);
```

Use the node surface when geometry and hierarchy should decide what receives the event. Use the stage surface when you care about the pointer independently of a particular hit target—for example, camera controls, diagnostic overlays, or global input state.

That separation keeps low-level input available without making every interaction manually rediscover which node was under the pointer.

## Visible geometry is the starting point

By default, GraphX resolves pointer hits from scene geometry and hierarchy.

That means transforms matter automatically. If a node moves, scales, rotates, or lives under transformed parents, the pointer system follows the same scene relationships.

And as we saw in [Visibility and activity](#visibility-and-activity), a hidden or inactive branch does not participate in pointer routing.

The defaults cover a lot, but interaction sometimes wants geometry different from rendering. The next chapter will look at hover, automatic capture, composite targets, custom hit areas, and cursors—the tools that let pointer behavior become more deliberate without changing what the scene looks like.
