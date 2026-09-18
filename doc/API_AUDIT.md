# GraphX 2 API audit

Status: pre-release public-surface contract for the local GraphX 2 migration.

## Library boundary

GraphX remains one pub package. Its implementation is one private library at
`lib/src/graphx_impl.dart` so hot-path internals can share private state without
artificial package boundaries.

Supported entrypoints:

- `package:graphx/graphx.dart` — application and engine API.
- `package:graphx/graphx_extension.dart` — supported seams for custom hosts,
  render backends, projection/plugin integrations, and ownership inspection.
- `package:graphx/graphx_debug.dart` — tracing, timing, and tooling-only API.

Consumers must not import `package:graphx/src/...`. Anything below `lib/src`
is implementation detail even when its declaration is non-private inside the
implementation library.

## Core API that belongs in graphx.dart

The default entrypoint owns the coherent retained application model:

- scene ownership and lifecycle: GNode, GRoot, GStage, GRuntime
- transforms and geometry: GPoint, GRect, GBounds, GMatrix2, GMath
- rendering primitives: GGraphics, GShape, GImage, GText, GIcon, GCanvasNode
- texture and asset ownership
- compositing: alpha, blend, clips, masks, filters, color transforms, cache
- pointer and keyboard input, hit testing, gestures and cursors
- focus, semantic actions, accessibility semantics
- portals and Flutter hosting
- render views, viewport culling, snapshots and offscreen render sessions
- diagnostics counters exposed through GStage.stats

These are core because removing them would leave GraphX unable to host a
complete retained interactive application with one dependency.

## Extension-author API

`graphx_extension.dart` exposes lower-level contracts that are supported but
should not dominate ordinary autocomplete:

- GStageHost
- GCanvasRenderer
- GCanvasSubtreePainter
- GInputHostDispatch
- GInteractionCoordinateMapper
- GInteractionGeometryInvalidation
- GFilterOwnership
- GImageInstanceOwnership

Add a symbol here only when an external package needs a stable contract that
cannot be expressed through the normal scene API.

## Debug/tooling API

`graphx_debug.dart` owns:

- trace configuration, records and sinks
- timers
- effect-bounds inspection

The inspector VM-service implementation itself remains private. Debug tooling
may depend on this entrypoint without making tooling vocabulary part of the
ordinary application API.

## Naming decisions

- Product-facing names use exact GraphX casing: GraphXView, GraphXConfig,
  GraphXController, GraphXReloadMode, GraphXSceneBuilder.
- Retained engine primitives keep the compact G prefix.
- GNode identity metadata is named: `GNode(name: 'player')`.
- Subclasses that expose identity metadata also use named `name`.
- Primary semantic payload may remain positional, for example `GText('hello')`
  and `GImage(texture)`.
- GStage keeps its root positional and uses named configuration:
  `GStage(root, maxDelta: ..., inputEnabled: ..., runtime: ...)`.
- Generic names that pollute a consumer namespace are avoided. The old
  `Math` helper is `GMath`; the shared disposal contract is private.
- Signal callback typedefs use the package prefix: GSignalCallback and
  GSignalCallback0.

## Deliberately hidden implementation types

Examples include GCallbackRoot, RenderGraphXSurface, the generic internal
disposal contract, renderer bookkeeping, inspector runtimes, portal hosts and
other bridge implementation objects. Their existence is not a compatibility
promise.

## Package boundaries

Do not split fundamental application capabilities into packages merely to make
core smaller. Focus, semantics, portals, text, images, input and composition
remain in `graphx`.

Future packages should represent substantial optional domains:

- graphx_motion
- graphx_camera
- graphx_gpu
- graphx_paths
- graphx_svg
- graphx_particles
- graphx_layout
- graphx_ui
- graphx_audio
- graphx_arcade
- graphx_maps
- graphx_gxf or a standalone GXF adapter

`graphx_gpu` stays outside core initially. It may depend on Flutter GPU and
provide accelerated execution/resources, but GraphX continues to own scene
hierarchy, lifecycle, transforms, bounds, input, focus and semantics.

## Pre-release decisions still open

### Remove HTTP policy from core

Core currently depends on `package:http` because GAssets has a default network
loader. The preferred release direction is to keep GAssetUrlLoader as the
injection seam and remove built-in HTTP fetching from core. Network policy can
live in application code or a small optional integration package. This would
remove a dependency and keep asset ownership separate from transport policy.

### Review manager names without forced churn

GPointerManager, GKeyboardManager and GFocusManager are accurate but expose
implementation-oriented vocabulary. Rename them only if a replacement makes
call sites materially clearer; do not rename solely for cosmetic consistency.

### Review advanced render-view surface

GRenderView/GRenderGroup/GViewportGroup are proven and useful for camera and
multi-view packages. Keep them in core if they remain the stable generic
mechanism. Higher-level camera policy belongs outside core.

## Release gate

Before the first public prerelease:

1. flutter analyze is clean.
2. full tests pass.
3. public examples import only graphx.dart.
4. extension tests import graphx_extension.dart only when exercising a supported
   extension seam.
5. debug tests import graphx_debug.dart for tooling APIs.
6. no production code outside this package imports graphx/src.
7. resolve the core HTTP dependency decision.
8. run pub publish --dry-run after publish metadata and license are finalized.
