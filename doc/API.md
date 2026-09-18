# API notes

GraphX should stay easy to approach from one import:

```dart
import 'package:graphx/graphx.dart';
```

The main library contains the parts most applications are expected to use: scene nodes, drawing, text and images, transforms, input, focus, semantics, portals, compositing, render views, and the Flutter host.

Two extra entrypoints exist for less common work:

- `graphx_extension.dart` for custom hosts and integrations.
- `graphx_debug.dart` for tracing and tooling.

Code under `lib/src` is private.

## Naming

GraphX types use the `G` prefix for scene/runtime objects and `GraphX` for product-facing Flutter types.

```dart
GNode(name: 'player');
GShape(name: 'background');
GText('Hello');
GImage(texture);

GStage(
  root,
  maxDelta: 1 / 60,
  inputEnabled: true,
);
```

Names and configuration should be named arguments. The main content of an object can stay positional when that makes the API read naturally.

## Core

The core should be useful on its own. Drawing, text, images, input, focus, accessibility, portals, and normal composition belong here.

Optional features can live outside the core when they are ready. We do not need to design those package boundaries in advance.

## Signals

GraphX exposes one mutable signal type: `GSignal<T>`, plus `GSignal0` for events without a
payload. The same object owns subscriptions and synchronous emission; there is no separate
read-only view or controller type.

When porting packages into the repository, replace `GSignalView<T>` with `GSignal<T>`,
`GSignalView0` with `GSignal0`, and return the signal directly instead of `.view`. Engine-owned
signals may also be emitted by application code. That freedom is intentional: signal ownership is
an API convention, not a capability boundary.

## Before the first release

- finish the public API pass
- review the built-in HTTP asset loader
- add polished examples and demos
- settle package metadata and license
- run a full publish dry-run
