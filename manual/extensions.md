# Extensions

Most people using GraphX should never need this chapter.

An application normally imports:

```dart
import 'package:graphx/graphx.dart';
```

That gives you the scene tree, drawing, input, assets, views, filters, portals, and the rest of the normal engine API.

`graphx_extension.dart` exists for a different job: **building packages that plug into GraphX itself.**

## Think package integration, not application code

Imagine you are writing a GraphX package that provides a projected 2.5D scene, a custom Flutter host, or a specialized input bridge.

At some point the package may need to participate in engine work that an ordinary scene never touches:

```text
paint an existing GraphX subtree from a specialized renderer
feed platform input into GraphX's canonical routing
map interaction coordinates through a custom projection
host a stage somewhere other than GraphXView
```

Those are extension problems.

A normal game, visualization, editor, or UI built *with* GraphX does not become an extension merely because it is large or sophisticated.

## `graphx_extension.dart` is the supported advanced surface

A package author can opt into:

```dart
import 'package:graphx/graphx_extension.dart';
```

It includes the normal GraphX API plus a deliberately small set of lower-level contracts intended for integration packages.

The split is similar in spirit to Flutter having ordinary widget APIs and deeper rendering/platform APIs: you only reach for the lower layer when the thing you are building actually participates in that layer.

GraphX keeps three public entry points with different audiences:

```text
graphx.dart
  build scenes and applications

graphx_extension.dart
  build packages that integrate with GraphX internals at supported seams

graphx_debug.dart
  tracing, diagnostics, inspection/tooling
```

The important part is that all three are still **public package libraries**.

## Example: host GraphX without `GraphXView`

`GraphXView` is the normal Flutter host. It schedules updates, paints the stage, forwards platform input, updates the cursor, and connects the retained engine to Flutter's lifecycle.

A package building a different host boundary needs to provide those responsibilities itself.

`GStageHost` is the supported contract for that side of the engine:

```text
schedule an update
schedule a paint
update the platform cursor
```

`GInputHostDispatch` feeds pointer, key, and pan/zoom events into the same GraphX input pipeline used by `GraphXView`.

So a custom host package does not have to copy GraphX hit testing or invent a parallel event router. It supplies the platform/host side and then hands canonical events back to the engine.

If you are simply embedding GraphX in a Flutter screen, none of this is necessary—use `GraphXView`.

## Example: project a GraphX subtree through another renderer

A 2.5D package may want to decide projection and ordering itself while still letting the existing GraphX subtree render normally.

That is what `GCanvasSubtreePainter` is for.

Conceptually:

```text
package decides projection / order
              ↓
GCanvasSubtreePainter
              ↓
existing GraphX subtree paints with its normal masks,
filters, caches, alpha, children, etc.
```

The package owns the extra projection logic without cloning GraphX's retained rendering model.

That matters because the alternative—converting every GraphX node into a second private render tree—would create two sources of truth for transforms, composition, and lifecycle.

## Custom projection also has to agree with interaction

If visuals are projected somewhere different from their ordinary affine node transform, pointer/focus geometry needs the same mapping or interaction will no longer line up with what the user sees.

`GInteractionCoordinateMapper` gives a specialized node/package a supported way to map coordinates through that projection.

When the projection changes:

```dart
invalidateInteractionGeometry();
```

lets GraphX reconcile dependent state such as hover.

The useful idea is broader than the API name:

> **visual geometry and interaction geometry must describe the same world.**

The extension surface gives packages a place to keep those two sides in sync.

## Dart extensions are another ecosystem tool

A GraphX package does not need core to contain every future feature.

Dart extension APIs let a package add focused vocabulary around GraphX types:

```dart
stage.camera2d
node.somePackageFeature
```

without adding storage/fields to every `GStage` or `GNode` in core.

GraphX itself already uses this style for optional features such as stage focus/render-view APIs.

This is especially useful for ecosystem packages whose state only exists when that package is installed and used.

## Why not import `package:graphx/src/...`?

In Dart packages, `lib/src/` conventionally contains implementation files rather than the supported package surface.

You *can* sometimes force an import such as:

```dart
import 'package:graphx/src/something_internal.dart';
```

but your package is then coupled to a file/class that GraphX is free to reorganize while preserving the public API.

A future refactor could move that implementation without being a public breaking change, and your package would break anyway.

That is the practical reason to stop at the public libraries:

```text
need ordinary engine behavior
  → graphx.dart

need a supported lower-level integration seam
  → graphx_extension.dart

need diagnostics/tooling
  → graphx_debug.dart

need something none of those expose
  → treat it as a missing integration capability and discuss/add a public seam
```

The last case is a design conversation for GraphX/package maintainers, not something an application developer should have to work around with private imports.

## The short version

If you are building **with GraphX**, import `graphx.dart`.

If you are building something that plugs **into GraphX itself**, inspect `graphx_extension.dart`.

If neither public surface can express the integration cleanly, that is the point where the engine/package API should be improved instead of reaching into `src/`.
