# GraphX 2

GraphX is a retained-mode 2D scene, rendering, interaction, accessibility, and Flutter-composition engine.

This repository is the clean GraphX 2 core. It is currently private/local while the public API and release baseline are stabilized.

Core owns the coherent application runtime: scene hierarchy, lifecycle, transforms, bounds, rendering, graphics, images, text, input, focus, actions, semantics, portals, Flutter hosting, compositing, and diagnostics.

Specialized domains such as motion, cameras, maps, physics, audio, SVG/SWF/GXF, particles, authoring, and Flutter GPU execution remain outside core unless multiple consumers prove a generic primitive belongs here.

Development:

```bash
flutter pub get
flutter analyze
flutter test
```

The implementation was distilled from the proven Satechi core. See `doc/migration.md` for provenance and migration policy.
