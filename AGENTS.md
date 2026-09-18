# Development notes

GraphX is a performance-sensitive graphics package. Keep changes small, tested, and easy to reason about.

- Keep the public API compact and approachable.
- Preserve a single scene tree and runtime.
- Avoid allocations in hot paths where practical.
- Keep implementation details under `lib/src`.
- Group core implementation by ownership: scene tree, input, geometry, and resources each have a dedicated folder under `lib/src/core`. Do not add a new domain folder for a single helper file.
- Do not use Dart cascade notation (`..` or `?..`) in source, tests, examples, benchmarks, or documentation. Name the receiver and use explicit statements. Collection spread (`...`) is unrelated and remains allowed.
- Prefer measured changes over speculative abstractions.
- Run relevant tests and benchmarks when changing rendering, transforms, input, caching, or lifecycle behavior.
- Add optional features to the core only when they clearly belong there.

The source, tests, examples, and benchmarks are the reference for behavior.
