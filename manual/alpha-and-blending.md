# Alpha and blending

Put two opaque circles in a group, let them overlap, then fade the group to 50%.

There are actually two different pictures GraphX could produce.

## The cheap fade: alpha flows through the tree

Every node has `alpha`:

```dart
group.alpha = 0.5;
```

By default, GraphX does not render `group` into a temporary image just because its alpha changed. It carries the inherited alpha down the hierarchy instead.

If the tree is:

```text
root alpha 0.8
└── group alpha 0.5
    └── child alpha 0.25
```

then the child paints with an effective alpha of:

```text
0.8 × 0.5 × 0.25 = 0.1
```

There is no public `worldAlpha` property to keep synchronized. GraphX calculates the inherited value while rendering.

For most scene objects this is exactly what you want: it is simple, predictable, and avoids compositing the whole subtree into an offscreen layer.

The important renderer idea is **resolved state**. GraphX carries the effective alpha down the tree and lets each renderable apply it as close to the actual draw call as possible.

That is similar to Flutter's own performance guidance: applying opacity directly to primitive paints/images can be cheaper than wrapping a group in an `Opacity`-style offscreen composition.

There is one practical caveat. Some native Flutter primitives cannot consume GraphX's inherited render state directly after they have been built. `GText`/`GIcon` are examples, so GraphX may use a tightly-bounded `saveLayer()` fallback around that one renderable. That is still different from isolating an entire node subtree for group compositing.

## Overlap reveals the difference

Now give `group` two opaque children that overlap.

With normal inherited alpha, each child paints at 50% into the destination. Where the children overlap, those two translucent paints accumulate.

So this:

```dart
group.alpha = 0.5;
```

means roughly:

```text
paint child A at 50%
paint child B at 50%
```

It does **not** mean:

```text
paint the complete group normally
then fade the finished group to 50%
```

Those pictures differ wherever the children overlap.

That distinction is the reason composited alpha exists.

## Fade the finished subtree as one image

Ask GraphX to isolate the subtree first:

```dart
group.alpha = 0.5;
group.compositeMode = GCompositeMode.layer;
```

Now GraphX conceptually does this:

```text
1. render group + descendants at their internal alpha
2. keep that result in an offscreen layer
3. composite the finished layer at group.alpha
```

The overlapping children combine **inside** the layer before the group's 50% fade is applied.

The layer isolates that node's local alpha. Alpha inherited from ancestors still arrives from above in the normal way. If a whole larger branch must fade as one finished image, put the layer at the ancestor whose alpha should be applied once.

This is closer to putting the whole group in Photoshop and lowering the layer opacity.

It costs more because `Canvas.saveLayer()` creates an isolated compositing surface. Flutter's rendering guidance treats `saveLayer()` as an expensive operation because it needs an offscreen buffer and may cause a GPU render-target switch before that buffer is composited back.

The exact cost varies by backend, device, layer size, and effect. The useful rule is not “layers are bad”; it is **do not ask for group compositing when primitive-level inherited state already gives the picture you want**.

## `auto` is usually the right mode

The default is:

```dart
GCompositeMode.auto
```

`auto` stays on the direct path when it can. Plain alpha by itself remains inherited/direct.

GraphX automatically isolates when a feature actually requires a finished subtree image, such as:

- a node blend mode other than `srcOver`;
- an alpha mask;
- filters.

You normally do not need to manage those layers yourself.

`GCompositeMode.layer` is the explicit request when **you** need whole-subtree compositing semantics, particularly for group alpha.

There is also `GCompositeMode.direct`, which means “do not isolate this node.” It is mainly an advanced/performance assertion: combining it with a feature that requires isolation is invalid rather than silently changing semantics.

## Blend modes change how the subtree meets what is behind it

Flutter already exposes `dart:ui.BlendMode`, and GraphX uses the same type:

```dart
glow.blendMode = BlendMode.plus;
```

or:

```dart
shadow.blendMode = BlendMode.multiply;
```

A non-default node blend mode applies when the **finished node subtree** is composited into the destination, so GraphX `auto` isolates that subtree automatically.

That is different from blend modes used inside `GGraphics` fills/strokes, which affect individual drawing operations. Node `blendMode` is a composition decision for the node and its descendants as a unit.

A few familiar experiments are worth trying:

```dart
node.blendMode = BlendMode.multiply;
node.blendMode = BlendMode.screen;
node.blendMode = BlendMode.plus;
node.blendMode = BlendMode.difference;
```

The result depends on the pixels already behind the node, so blend modes are much easier to learn by moving colorful shapes over each other than by memorizing Porter-Duff equations.

## Layers are powerful, not free

An isolated layer needs an offscreen render target and another compositing step.

That does not mean “never use layers.” Masks, filters, group opacity, and creative blend modes are exactly why compositing exists.

It means there is value in knowing which picture you are asking for:

```text
inherited alpha
    ↓
cheap per-child fade

isolated layer alpha
    ↓
fade the finished subtree once
```

[Performance](#performance) goes deeper into measuring those choices. For now, if two overlapping children look unexpectedly darker while fading, you already know where to look.
