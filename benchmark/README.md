# GraphX performance benchmarks

This directory contains engineering instrumentation for GraphX. It is not a
single "GraphX score" and the numbers are not intended to be compared across
unrelated workloads.

## Canonical baseline

`performance_baseline.dart` is the canonical numeric baseline. It uses the
shared harness in `performance/benchmark_harness.dart` and emits both readable
rows and one JSON object per result:

```text
GRAPHX_BENCHMARK_RESULT {...}
```

The schema identifier is `GRAPHX_BENCHMARK_V1`.

Run from the package root:

```sh
dart run benchmark/run.dart --baseline --device=macos
dart run benchmark/run.dart --baseline --device=chrome
```

The runner creates a disposable Flutter host under
`.dart_tool/graphx_benchmark_host`. GraphX remains a package-only repository;
benchmarking does not add macOS or web runner boilerplate to the package.

Baseline runs use profile mode and keep the host alive after printing
`GRAPHX_BENCHMARK_COMPLETE`; quit the Flutter runner when the capture is
complete. This keeps native and web collection behavior consistent and avoids
racing the host service connection.

Do not compare debug-mode results. The harness prints a warning if it detects a
debug build.

## Metrics

The canonical result includes:

- p50 and p95
- minimum, maximum and arithmetic mean
- warmup count and measured sample count
- logical workload size and operations per sample
- p50 nanoseconds per logical operation where that is meaningful
- profile/release/debug mode
- native/web target, target platform and device pixel ratio
- stopwatch frequency used for timing conversion
- workload-specific configuration

The normal synchronous baseline uses 12 warmups and 41 measured samples.
Expensive asynchronous raster-cache rebuilds use 2 warmups and 21 samples.
Samples are captured as stopwatch ticks and converted after percentile selection,
so sub-microsecond results are preserved when the target clock supports them.

`record` means synchronous GraphX traversal and Canvas command recording.
PictureRecorder creation and `endRecording()` are deliberately outside the
timed region. It does **not** mean GPU raster time, compositor time or presented
frame time.

`rasterize` / `rebuild` cache metrics include the asynchronous picture-to-image
work performed by the GraphX raster cache.

The visual lab reports host frame cadence and therefore answers a different
question from the numeric `record` metric.

## Baseline workloads

The baseline intentionally separates mutation from rendering where possible.

### Static retained scene

Runs stable retained scenes at 100, 1,000 and 10,000 painted nodes. Setup and
scene construction are excluded.

### Transform invalidation

Measures:

- mutation of position, rotation and scale across all retained leaves
- recording immediately after all leaf transforms change
- recording after only parent transforms change

This exposes both mutation-path invalidation and lazy world-transform
resolution.

### GGraphics

Measures:

- retained small-shape recording
- `clear()` + redraw mutation cost
- recording after every shape was cleared and rebuilt
- a smaller set of more complex retained paths
- clear/redraw of those complex paths

The existing `graphics_line_pattern_benchmark.dart` remains the specialist
coverage for retained dash/pattern phase changes.

### Raster cache

Measures separately:

- uncached recording
- warm cached recording
- cold cache creation after `clear()`
- content invalidation followed by rebuild
- moving a cached node without rebuilding its own pixels
- same-stage reparenting inside a cached subtree followed by rebuild

Cache results report the captured pixel dimensions where useful. They do not
imply that caching is always beneficial.

### Scene mutation

Measures:

- visibility changes
- alpha changes
- intrinsic bounds invalidation
- preallocated add/remove lifecycle work
- same-stage reparenting

Allocation of new nodes is deliberately excluded from the add/remove sample so
structure/lifecycle cost is not confused with object allocation.

### Hit testing and pointer routing

Measures both geometry-only inspection and the real pointer router:

- shallow reverse traversal
- transformed siblings
- deep single-child chains
- many interactive siblings
- the same interactive subtree with pointer routing disabled at its parent

The pointer benchmark uses the public external-host dispatch API, so it follows
the same canonical routing path as `GraphXView`.

### Images and batching

Compares `GImage` nodes with `GImageBatch` at 100, 1,000 and 10,000 instances:

- recording
- transform mutation
- per-instance tint mutation

Texture/image creation is outside measured samples.

## Visual stress lab

`performance_lab.dart` is intentionally separate from the numeric baseline:

```sh
dart run benchmark/run.dart --lab --device=macos
dart run benchmark/run.dart --lab --device=chrome
```

For a deterministic launch/switching smoke check, add `--smoke`. Smoke mode
cycles through every scenario at 1,000 objects and emits
`GRAPHX_PERFORMANCE_LAB_SCENARIO` plus a final
`GRAPHX_PERFORMANCE_LAB_SMOKE complete` marker. Normal lab behavior is
unchanged when the flag is absent.

It exposes selectable stress scenarios for:

- static retained nodes
- all-node transform animation
- GGraphics clear/redraw every frame
- moving live vs raster-cached subtrees
- moving independent images vs `GImageBatch`
- pointer-routing-heavy scenes

The HUD shows active workload, object count, host FPS, latest frame interval,
cache state and pointer event activity where relevant. It is an engineering
lab, not a product demo.

## Native vs web

Native and web timings must be treated as separate populations. The runtime,
compiler, browser, Canvas backend and scheduling model differ.

The same workload definitions can be launched on macOS and Chrome, but do not
claim a direct ratio unless the browser, Flutter revision, rendering backend,
machine, DPR and run conditions are also controlled and recorded externally.

The current schema records target/platform/DPR/build mode. It does not yet
capture browser version, Flutter engine revision, web renderer selection,
thermal state or machine model automatically.

## Allocations and GC

Stopwatch timings do not provide portable allocation counts. In particular,
graphics clear/redraw intentionally exercises an allocation-prone mutation
path, so GC pauses are part of the observed p95 signal but are not themselves
an allocation measurement.

For allocation investigations, run one visual-lab scenario in profile mode and
use the Dart/Flutter DevTools Memory allocation profile around a fixed interval.
Capture at least:

- GGraphics clear/redraw
- all-node transform mutation
- static traversal
- hit testing / pointer routing
- cache invalidation/rebuild

Compare retained object deltas and allocation rates, not only heap size after a
GC. Keep allocation evidence with the benchmark campaign; do not fold it into
the portable timing schema until native and web collection semantics are
equivalent enough to be meaningful.

## Existing specialist benchmarks

The pre-existing files remain because each still probes a distinct subsystem.
They are **not** canonical cross-file comparison input because their warmup,
sample count and output conventions differ.

| Benchmark | Useful signal | Baseline caveat |
| --- | --- | --- |
| `animated_graphics_benchmark.dart` | retained animation vs packed rendering, record and raster work | bespoke sampling/output; useful specialist experiment |
| `cache_benchmark.dart` | cache/filter build and warm rendering | small samples make its historical p95 effectively a tail/max sample |
| `external_host_bridge_benchmark.dart` | external-host sync and render bridge overhead | targeted bridge microbenchmark |
| `filter_benchmark.dart` | filter mutation, bounds, recording and layer pressure | expected expensive path; bespoke small-sample statistics |
| `graphics_bounds_benchmark.dart` | path bounds strategies | geometry microbenchmark, not frame performance |
| `graphics_line_pattern_benchmark.dart` | retained line-pattern phase/rebuild behavior | specialist GGraphics path |
| `inspector_activity_benchmark.dart` | inspector activity behavior | integration/protocol probe rather than timing baseline |
| `inspector_benchmark.dart` | large-scene inspector RPC latency | RPC/setup timing is not comparable to render samples |
| `inspector_capture_benchmark.dart` | inspector capture behavior | integration/protocol probe |
| `render_view_benchmark.dart` | render-view/mask traversal | useful specialist traversal case with its own sampling |
| `semantics_benchmark.dart` | semantics/transform mutation | non-render subsystem with its own sampling |

No existing benchmark is removed by this baseline because there is no exact
duplicate whose information content is strictly subsumed.

## Comparison discipline

For a change intended to affect performance:

1. Run at least three campaigns under the same build mode and target.
2. Compare the same workload/count/configuration keys.
3. Look at p50 and p95 together.
4. Treat isolated tail spikes as noise until reproduced.
5. Re-run after cooling/idle time when a long campaign may have changed thermal
   conditions.
6. Use the visual lab or profiler when a numeric regression needs attribution.

A benchmark that proves only that a synthetic case is fast is not sufficient
evidence for an engine optimization.
