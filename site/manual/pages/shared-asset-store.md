# The shared asset store

A texture can outlive the node that first asked for it.

That is why assets do not belong to `GImage`, `GText`, or any other scene object. They belong to the runtime behind the stage.

## `stage.assets` is runtime state

Once a node is attached, the shortest path is:

```dart
final assets = stage.assets;
```

That is the same store exposed by:

```dart
final assets = stage.runtime.assets;
```

`GStage` owns or borrows a `GRuntime`, and `GRuntime` owns one `GAssets` store.

```text
GraphXView / GStage
        ↓
     GRuntime
        ↓
      GAssets
        ↓
bytes / textures / sequences / custom cached values
```

This matters because a scene node is not the right lifetime boundary for decoded resources. Remove one `GImage` and the texture may still be needed by ten other nodes.

## Repeated requests share the same cached work

The default loaders cache unless you opt out:

```dart
final first = stage.assets.texture('images/player.png');
final second = stage.assets.texture('images/player.png');
```

If the first decode is still running, the second request does not start another decode. Both callers await the same cached future.

Once completed, later calls receive the cached texture.

That means caching protects both sides of the load:

```text
request A ─┐
           ├─ one read/decode ─→ cached GTexture
request B ─┘
```

The same principle applies to the general `load()` API, so format packages can share their own parsed/decoded objects through the runtime store as well.

## Cache identity includes the operation

The store does not treat an asset path as one universal value.

These are different cached requests:

```dart
await assets.bytes('images/player.png');
await assets.texture('images/player.png');
```

And decode options participate in image/texture cache identity too:

```dart
await assets.texture(
  'images/player.png',
  targetWidth: 64,
);

await assets.texture(
  'images/player.png',
  targetWidth: 256,
);
```

Those are different decoded resources, so they do not accidentally collide just because the source path matches.

## Failed loads do not poison the cache forever

If a cached loader fails, GraphX removes that failed entry.

A later request can try again instead of repeatedly receiving a permanently cached failure.

That behavior is especially relevant for network/custom loaders, but it also keeps tests and dynamic asset pipelines easier to reason about.

## The store can cache your own objects too

`GAssets` is not limited to built-in texture loaders:

```dart
final data = await stage.assets.load<MyLevelData>(
  'level-1',
  () => parseLevel('level-1'),
);
```

The key can be any object, and the loader can return any non-null Dart object.

That is intentional: extension/format packages can share expensive parsed state through the same runtime without adding package-specific caches to `GStage`.

For values you already have, `set()` can install them directly:

```dart
stage.assets.set('level-1', data);
```

`has()` and typed `get<T>()` are available when you need to inspect the store synchronously.

## Cache lifetime follows the runtime

A default `GraphXView` gets a runtime for its stage. When that owned stage/runtime is disposed, the asset store disposes cached GraphX disposable resources such as owned textures and texture sequences.

That is different from merely removing a node from the scene.

You can also remove one entry or clear the cache explicitly:

```dart
await stage.assets.remove('level-1');
await stage.assets.clear();
```

The store disposes disposable cached values it owns when those entries leave the cache.

## Several views can share one cache

Sometimes separate GraphX views should not decode the same image twice.

A shared `GRuntime` lets several descendant `GraphXView`s use the same `GAssets` instance:

```dart
final runtime = GRuntime();

GRuntimeProvider(
  runtime: runtime,
  child: const MyApp(),
);
```

A descendant `GraphXView` picks up that runtime from Flutter automatically.

Now two stages can request the same cached texture and converge on the same runtime resource instead of maintaining unrelated stores.

The provider does not own/dispose the runtime for you. The code that created a shared `GRuntime` is responsible for its lifetime.

We will return to runtime sharing in its own chapter. For now, keep the ownership chain in mind:

**nodes use assets; stages expose assets; runtimes own assets.**
