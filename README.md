# GraphX 2

GraphX is a retained-mode 2D scene, rendering, interaction, accessibility, and
Flutter-composition engine.

This repository is the clean GraphX 2 core. It is currently private/local while
the public API and release baseline are stabilized.

A normal application imports one library:

```dart
import 'package:graphx/graphx.dart';
```

That entrypoint includes the coherent application runtime: scene hierarchy,
lifecycle, transforms, bounds, graphics, images, text, input, focus, actions,
semantics, portals, Flutter hosting, compositing, render views, snapshots and
diagnostics.

The same package also provides two deliberately narrower advanced entrypoints:

- `package:graphx/graphx_extension.dart` for custom hosts/backends and plugin
  authors.
- `package:graphx/graphx_debug.dart` for tracing and tooling.

Anything under `package:graphx/src/...` is private implementation and not a
compatibility contract.

Specialized domains such as motion, cameras, maps, physics, audio, SVG/SWF/GXF,
particles, authoring, and Flutter GPU execution remain outside core unless
multiple consumers prove a generic primitive belongs here.

Development:

```bash
flutter pub get
flutter analyze
flutter test
```

The implementation was distilled from the proven Satechi core. See
`doc/migration.md` for provenance and `doc/API_AUDIT.md` for the public API
boundary.
