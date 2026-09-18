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

## Before the first release

- finish the public API pass
- review the built-in HTTP asset loader
- add polished examples and demos
- settle package metadata and license
- run a full publish dry-run
