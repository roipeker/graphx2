# GraphX agent contract

GraphX is the standalone public-core successor distilled from the Satechi engine work.

Start with `README.md`, `doc/migration.md`, and the implementation. Source and tests are authoritative.

Rules:
- Keep this repository a single publishable `graphx` package.
- Preserve one scene/runtime model; do not introduce parallel trees or clocks.
- Core may own scene, render, input, focus, semantics, portals, Flutter hosting, and generic composition primitives.
- Specialized domains belong in future `graphx_*` packages unless cross-domain evidence justifies promotion.
- Keep hot paths allocation-aware and invalidation-driven.
- Do not depend on Satechi source or local path packages.
- Do not add GitHub remotes or publish without explicit release work.
- Migrate behavior first; redesign only after equivalent tests are green.
- Performance changes require measurement when an existing benchmark can prove the claim.

Satechi is a read-only reference during migration.
