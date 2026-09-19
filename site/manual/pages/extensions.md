# Extensions

Most GraphX applications should import one library:

```dart
import 'package:graphx/graphx.dart';
```

That is the application API.

But a rendering engine eventually attracts packages that need to go deeper: custom cameras, 2.5D projection, alternative hosts, format runtimes, custom input bridges, tooling.

Those packages should not reach into `lib/src/`.

## The supported lower-level surface has its own library

Extension authors can import:

```dart
import 'package:graphx/graphx_extension.dart';
```

That library re-exports the normal GraphX API plus a small set of supported lower-level contracts.

The separation is intentional:

```text
graphx.dart
  normal application code

graphx_extension.dart
  package authors / custom hosts / rendering integrations

graphx_debug.dart
  diagnostics / tracing / tooling
```

A package can therefore need more engine access without turning private implementation files into accidental public API.

## A custom host can drive a stage without `GraphXView`

`GStageHost` is the host-side scheduling contract:

```text
schedule an update tick
schedule paint
update the platform cursor
```

`GInputHostDispatch` lets that host feed pointer/key/pan-zoom events into the same canonical input pipeline used by `GraphXView`.

That is enough for a package to build a different host boundary without duplicating GraphX node routing logic.

It is an advanced API; normal Flutter applications should keep using `GraphXView`.

## Projection packages can own a render boundary without owning another scene tree

`GCanvasSubtreePainter` can paint an existing GraphX subtree inside an active `GRenderContext`.

A package implementing projected 2.5D planes, for example, can decide ordering/projection and then ask GraphX to paint the actual retained subtree:

```text
extension package chooses projection/order
             ↓
GCanvasSubtreePainter
             ↓
existing GraphX nodes render normally
```

The nodes keep their alpha, filters, masks, caches, and descendants.

That preserves one of the core architectural rules: an advanced renderer should not quietly create a second competing scene graph.

## Interaction projections can teach hit testing the same geometry

`GInteractionCoordinateMapper` exists for retained nodes whose visual projection cannot be represented by the normal affine `localMatrix` alone.

A specialized node can map interaction coordinates to/from its parent projection, and GraphX pointer/focus/semantic geometry can follow that mapping.

When that projected geometry changes, `invalidateInteractionGeometry()` tells the engine to reconcile dependent interaction state such as hover.

Again, this is extension-author territory—not something a normal button should ever need.

## Stage extensions are also part of the growth model

Earlier we saw features such as:

```dart
stage.focus
stage.renderViews
stage.hitTest(...)
```

present themselves naturally through Dart extension APIs.

External packages can use the same language mechanism to add focused stage/node APIs around their own state, rather than requiring GraphX core to become a giant registry of every package that may ever exist.

That is an important part of keeping the foundation small while still allowing a larger ecosystem to grow around it.

## Private `src/` imports are the line not to cross

If a package needs something that is only available through GraphX private implementation files, that is not permission to import them.

It is an API-friction signal.

The healthier path is to identify the narrow capability the package actually needs and decide whether it belongs in `graphx.dart`, `graphx_extension.dart`, `graphx_debug.dart`, or nowhere public at all.

A small supported boundary is much easier to evolve than an ecosystem coupled to implementation details.
