# Diagnostics

When a scene feels wrong, guessing is expensive.

GraphX exposes enough live information to answer questions such as:

- are we visiting far more nodes than expected?
- did this effect start creating save layers?
- is a raster cache rebuilding constantly?
- are text paragraphs being laid out every frame?
- did a transform path lose its cache hits?

## Cheap scene facts are always available

The simplest number does not require instrumentation:

```dart
print(stage.stats.scene.nodeCount);
```

That is maintained by the stage as nodes attach/detach.

## Turn detailed instrumentation on deliberately

Detailed counters/timers are off until requested:

```dart
stage.stats.enabled = true;
```

Then you can inspect frame timing:

```dart
print(stage.stats.frame.fps);
print(stage.stats.frame.frameMilliseconds);
print(stage.stats.frame.maxFrameMilliseconds);
```

and synchronous update/render timing:

```dart
print(stage.stats.frame.update.lastMicroseconds);
print(stage.stats.render.paint.lastMicroseconds);
```

The render counters expose what GraphX actually did:

```dart
print(stage.stats.render.nodesVisited.value);
print(stage.stats.render.nodesPainted.value);
print(stage.stats.render.saveLayers.value);
print(stage.stats.render.masksApplied.value);
print(stage.stats.render.clipsApplied.value);
```

Those counters accumulate until reset:

```dart
stage.stats.reset();
```

That makes a small experiment easy: reset, perform one interaction or animation window, inspect what changed.

## Cache diagnostics answer “is this helping?”

```dart
print(stage.stats.cache.active);
print(stage.stats.cache.retainedBytes);
print(stage.stats.cache.rasterize.averageMicroseconds);
```

Combine that with the per-node cache counters from [Caching](#caching) and you can see whether a cache is stable or just converting paint work into repeated rasterization work.

## Transform counters expose hidden geometry work

```dart
print(stage.stats.transform.invalidations.value);
print(stage.stats.transform.worldMatrixUpdates.value);
print(stage.stats.transform.worldMatrixCacheHits.value);
print(stage.stats.transform.localToGlobal.value);
print(stage.stats.transform.globalToLocal.value);
```

This is particularly handy in editors and interaction-heavy scenes where transforms may be correct visually but accidentally recomputed much more often than intended.

## Text has its own retained-layout counters

```dart
print(stage.stats.text.paragraphBuilds.value);
print(stage.stats.text.paragraphLayouts.value);
print(stage.stats.text.paragraphPaints.value);
```

If a supposedly static label is rebuilding/layouting every frame, those numbers make the problem visible.

## `trace()` is not just another `print()`

For structured development logging, import the debug surface:

```dart
import 'package:graphx/graphx_debug.dart';
```

Then:

```dart
trace('player', player.x, player.y);
```

`trace` is a callable `GTrace` object rather than a thin alias to `print()`. It can attach caller information, filter by level, route output to the console/developer stream, use categories, and send records to a custom sink.

Create a category once:

```dart
final inputTrace = trace.category('input');

inputTrace('down', event.x, event.y);
```

or raise the level:

```dart
inputTrace.warn('pointer capture looked suspicious');
```

In release/product builds tracing is disabled by default.

That is why GraphX has `trace()` alongside ordinary Dart `print()`: `print()` is fine for a throwaway line; `trace` is meant for diagnostics you may want to keep organized while the engine/app grows.

## Measure a question, not everything at once

The counters are most useful when you already have a hypothesis.

“Why did this hover effect get expensive?” → inspect save layers/filter/cache behavior.

“Why does moving the camera allocate/recompute so much?” → inspect transform updates/cache hits.

“Why did this screen start missing frames?” → inspect frame/update/render timing, then profile the relevant section in Flutter/Dart tooling.

GraphX diagnostics are not a replacement for Flutter DevTools or platform profilers. They provide scene-specific facts those tools cannot infer from a generic Canvas call stack.
