# Changelog

## 2.0.0-dev.1

- Started the standalone GraphX 2 core from the proven Satechi core implementation.
- Preserved the retained scene, rendering, input, focus, semantics, portal, Flutter-hosting, compositing, diagnostics, tests, and benchmarks baseline.
- Removed Dart-workspace coupling and internalized the numeric buffer used by image batching.
- Kept the project local-only while the public API and release baseline are stabilized.
- Defined explicit application, extension-author, and debug entrypoints instead of exposing every implementation declaration.
- Standardized GraphX brand casing across public types.
- Made GNode identity metadata named (`GNode(name: ...)`) and applied the same rule to node subclasses.
- Made GStage configuration named while keeping its root as the positional payload.
