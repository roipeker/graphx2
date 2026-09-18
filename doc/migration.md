# GraphX 2 migration

Reference source: `/Users/cmdlab/Dev/satechi`
Reference revision: `8309f91e61bd154c7e2dac89b2c99766d2ec4d15`
Reference package: `packages/satechi`

Migration policy:
- Satechi remains read-only reference material.
- Migrate proven behavior before redesigning APIs.
- Preserve tests and benchmarks with each migrated capability.
- Remove monorepo/path dependencies from GraphX core.
- Keep focus, actions, semantics, portals, and Flutter composition in core.
- Keep specialized domains out of core unless independently justified.
- Flutter GPU stays an optional future execution package; it must not create a second scene/runtime model.
- No GitHub remote or pub.dev publication until the local release gates are accepted.

Initial import includes the complete current Satechi core implementation, tests, and benchmarks. Cleanup proceeds from this green reference baseline rather than deleting capabilities during the copy.
