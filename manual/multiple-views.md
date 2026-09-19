# Multiple views

One world does not have to mean one camera.

A game can show the main world and a minimap. An editor can show the same scene at full size and again in a tiny navigator. A split view can render the same retained nodes from two different transforms without duplicating the scene tree.

That is what `GRenderView` is for.

## One stage, two windows

A render view has two main pieces:

```text
viewport   → where this view appears on the GraphX surface
transform  → how stage/world coordinates map into that viewport
```

A main view might cover the whole stage:

```dart
final mainView = GRenderView(
  viewport: GRect(
    0,
    0,
    stage.width,
    stage.height,
  ),
  transform: GMatrix2(),
);
```

A minimap can use a smaller viewport and a zoomed-out transform:

```dart
final minimap = GRenderView(
  viewport: GRect(20, 20, 180, 120),
  transform: GMatrix2(
    0.2,
    0,
    0,
    0.2,
    0,
    0,
  ),
);
```

Register both:

```dart
stage.renderViews.add(mainView);
stage.renderViews.add(minimap);
```

That `both` is important. Once explicit render views exist, GraphX renders through those views instead of also doing the old implicit identity pass.

So if you add only a minimap, you get only a minimap.

## Move the camera, not the world

A render view transform maps world coordinates into view-local coordinates.

That means camera movement does not require moving every object in the scene:

```dart
mainView.transform.tx = -cameraX;
mainView.transform.ty = -cameraY;
mainView.invalidate();
```

The matrix is retained and mutable. After mutating it directly, call `invalidate()` so GraphX knows rendering and pointer mapping changed.

That same principle scales to zoom/rotation too.

For a higher-level camera package, those matrix changes can be wrapped in a friendlier API while the core render view stays small and allocation-free.

## Input follows the top-most eligible view

Pointer coordinates arrive in stage-surface space.

When explicit views are active, GraphX checks the registered views from front to back, finds the top-most enabled/input-enabled viewport under the pointer, and maps that point back into authoritative world coordinates before normal scene hit testing.

So a minimap can be interactive without creating a second interaction tree.

Disable input for a view when it should be visual only:

```dart
minimap.inputEnabled = false;
```

## View order is explicit

Views render in their collection order and can be reordered:

```dart
stage.renderViews.bringToFront(minimap);
```

or:

```dart
stage.renderViews.sendToBack(minimap);
```

This makes overlapping viewports predictable.

## Render masks can choose which branches each view sees

Sometimes the minimap should show the world but not the giant HUD floating over it.

`GRenderMask` and `GRenderGroup` provide a cheap retained visibility filter for explicit views:

```dart
final worldMask = GRenderMask.bit(0);
final hudMask = GRenderMask.bit(1);

final world = root.addChild(
  GRenderGroup(mask: worldMask),
);

final hud = root.addChild(
  GRenderGroup(mask: hudMask),
);
```

A view can select one or more masks:

```dart
mainView.mask = worldMask | hudMask;
minimap.mask = worldMask;
```

A rejected `GRenderGroup` lets GraphX skip that whole subtree for the view rather than visiting every descendant and deciding one-by-one.

You do not need render masks for ordinary scenes. They become interesting once one retained world is serving several genuinely different views.

## Resize means updating the viewport you own

Explicit view rectangles are retained objects too.

If the stage resizes, update the viewport that should follow it:

```dart
@override
void resize(double width, double height) {
  mainView.viewport.x = 0;
  mainView.viewport.y = 0;
  mainView.viewport.w = width;
  mainView.viewport.h = height;
  mainView.invalidate();
}
```

One scene, many views. That is the whole trick.
