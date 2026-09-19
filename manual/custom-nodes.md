# Custom nodes

GraphX comes with shapes, text, images, icons, shaders, and other visual nodes, but eventually a scene may want something more specific.

The important architectural idea is that you do not need to create a second render-object tree to do that.

A custom visual can still be a normal `GNode`.

## One hierarchy

GraphX² originally explored a split where a scene node could own a separate view or renderable component.

The final API went in the other direction: built-in visuals extend `GNode` directly.

```text
GNode
├── GShape
├── GText
├── GImage
├── GCanvasNode
└── your own node
```

That keeps transforms, children, lifecycle, input, visibility, bounds, and rendering attached to the same object.

It is related to the old GraphX/Flash display-list inheritance style, but GraphX² deliberately makes the base node container-capable. A text node, image node, or custom visual can still own children.

For small custom drawing there are two useful levels: `GCanvasNode` and a real `GNode` subclass.

## The direct Canvas escape hatch

Sometimes you already know exactly how to draw something with Flutter's `Canvas` and do not need a retained `GGraphics` description.

`GCanvasNode` is the smallest bridge:

```dart
final grid = GCanvasNode((context) {
  final paint = Paint();
  paint.color = context.resolveColor(Colors.blueGrey);
  paint.strokeWidth = 1;

  for (var x = 0.0; x <= 200; x += 20) {
    context.canvas.drawLine(
      Offset(x, 0),
      Offset(x, 120),
      paint,
    );
  }

  for (var y = 0.0; y <= 120; y += 20) {
    context.canvas.drawLine(
      Offset(0, y),
      Offset(200, y),
      paint,
    );
  }
});

root.addChild(grid);
```

The painter receives a `GRenderContext`. Its `canvas` is the same Flutter `Canvas` being used for the GraphX render pass.

`context.resolveColor()` is important for a solid-color custom primitive because it applies the inherited GraphX alpha and color transform before the color reaches the Canvas.

The node itself still participates in the normal scene transform. Move or rotate `grid` and GraphX applies that node transform before your painter runs.

## When `GCanvasNode` is useful

Think of it as a low-level fallback for drawing that is easiest to express directly with Canvas:

- a procedural debug overlay;
- a waveform or oscilloscope trace;
- a specialized chart primitive;
- a small visualization built around Canvas APIs GraphX does not wrap;
- an experiment before deciding whether the idea deserves a reusable node type.

It is deliberately less opinionated than `GShape`.

If the drawing is naturally described by retained paths and styles, `GShape`/`GGraphics` is usually the clearer choice. GraphX can retain that geometry for you instead of executing arbitrary Canvas drawing code each time the node paints.

## One catch: Canvas cannot tell GraphX your bounds

GraphX does not inspect arbitrary Canvas commands and try to guess what pixels you drew.

So `GCanvasNode` does not automatically acquire intrinsic bounds from its painter.

That matters for things such as self hit testing and geometry queries. If a one-off Canvas node has pointer behavior and needs explicit interaction geometry, a custom hit area can be enough:

```dart
grid.hitArea = GHitArea.rect(0, 0, 200, 120);
```

If the visual deserves real intrinsic bounds as part of its type, make a custom node instead.

## A reusable renderable node

Here is a deliberately small custom crosshair:

```dart
class CrosshairNode extends GNode {
  CrosshairNode({
    this.size = 32,
    this.color = Colors.cyan,
  }) {
    setPaintSelf(true);
  }

  final double size;
  final Color color;

  @override
  void computeSelfBounds(GBounds out) {
    final half = size * 0.5;
    out.set(-half, -half, half, half);
  }

  @override
  void paintSelf(GRenderContext context) {
    final half = size * 0.5;
    final paint = Paint();
    paint.color = context.resolveColor(color);
    paint.strokeWidth = 2;

    context.canvas.drawLine(
      Offset(-half, 0),
      Offset(half, 0),
      paint,
    );
    context.canvas.drawLine(
      Offset(0, -half),
      Offset(0, half),
      paint,
    );
  }
}
```

There are three important pieces here.

`setPaintSelf(true)` tells GraphX that this node has pixels of its own to paint.

`computeSelfBounds()` describes the node's intrinsic local geometry. Those bounds then participate in the normal GraphX bounds and pointer systems.

`paintSelf()` performs the actual rendering after GraphX has applied the node transform. The `GRenderContext` also carries inherited alpha/color state; direct Canvas code should use helpers such as `resolveColor()` when it needs that state applied to primitive colors.

Using it feels like any other node:

```dart
final marker = root.addChild(
  CrosshairNode(
    size: 40,
    color: Colors.orange,
  ),
);

marker.setPosition(160, 120);
marker.rotation = GMath.radians(15);
```

And because it is still a `GNode`, it can have children:

```dart
final caption = marker.addChild(
  GText(
    'target',
    style: const TextStyle(
      fontSize: 12,
      color: Colors.white,
    ),
  ),
);

caption.setPosition(28, -8);
```

The custom rendering did not create a new scene concept. It only taught one node how to paint itself.

## Mutable custom visuals need invalidation

The example above uses final rendering properties to keep the first custom node simple.

If a custom node later exposes mutable geometry or paint properties, its setters should tell GraphX what changed:

- call `invalidatePaint()` when rendered pixels changed;
- call `invalidateBounds()` when intrinsic geometry/bounds changed as well.

Transforms such as `x`, `y`, `scale`, and `rotation` already participate in GraphX's own invalidation machinery. You do not manually invalidate a custom node just because you moved it.

We will revisit invalidation and performance when the manual reaches caching and renderer behavior.

## Which level should you use?

A useful progression is:

- use `GShape` when retained vector geometry describes the visual well;
- use `GImage` / `GText` when the built-in visual already matches the job;
- use `GCanvasNode` for one-off direct Canvas drawing;
- subclass `GNode` when the visual deserves reusable behavior, intrinsic bounds, or its own small API.

The important part is that all four choices stay inside the same node hierarchy.

That is why custom rendering in GraphX can remain small: you are extending the scene model, not building another one beside it.
