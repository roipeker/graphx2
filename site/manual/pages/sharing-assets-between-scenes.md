# Sharing assets between scenes

Two GraphX views showing the same atlas should not necessarily decode it twice.

The sharing boundary is `GRuntime`.

## One runtime can back several stages

Create the runtime above the views that should share resources:

```dart
class AppState extends State<App> {
  final runtime = GRuntime();

  @override
  void dispose() {
    runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GRuntimeProvider(
      runtime: runtime,
      child: const AppBody(),
    );
  }
}
```

Descendant `GraphXView`s automatically pick up that runtime from Flutter.

Each view still owns its own `GStage` and scene tree. What they share is runtime-level state, currently most importantly the `GAssets` store.

```text
GRuntime
   └── GAssets
       ↑       ↑
    Stage A  Stage B
```

A texture requested by Stage A can therefore already be cached when Stage B asks for the same resource.

## Sharing is about lifetime, not scene ownership

A shared texture does not become a child of both scenes. The scenes still create their own `GImage` nodes:

```dart
final texture = await stage.assets.texture('images/logo.png');

final logo = addChild(GImage(texture));
```

The node is scene-local; the decoded resource is runtime-shared.

That separation is the same reason texture atlases and retained images can be reused by many nodes inside one stage.

## The provider does not dispose your runtime

`GRuntimeProvider` is an `InheritedWidget`. It exposes the runtime; it does not own its lifetime.

If your app created the shared `GRuntime`, your app should dispose it when that shared lifetime ends.

This is different from the default per-stage runtime, which the stage owns and disposes automatically.

## A shared cache is really shared

Calling:

```dart
await stage.assets.clear();
```

on one stage using a shared runtime clears the same cache seen by the other stages.

That is powerful, but it means cache invalidation should happen at the same conceptual level as the runtime. Do not casually remove/dispose a shared texture while live scene nodes are still using it.

`GAssets` is a cache/owner, not a reference-counted asset graph.

## Keep the runtime stable while retained scenes use its resources

`GraphXView` can react if the nearest `GRuntimeProvider` changes, but swapping runtimes underneath a retained scene changes the owner/cache for future loads.

Existing scene nodes may still hold resources obtained from the previous runtime.

For most applications, the simpler rule is better: establish the shared runtime above the relevant GraphX views and keep it stable for their lifetime. Treat runtime replacement as an explicit application-level migration, not ordinary widget rebuilding.

The next chapter shows how a shared runtime can also define how URL-backed assets are transported.
