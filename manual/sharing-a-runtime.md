# Sharing a runtime

Picture an app with a GraphX thumbnail preview, a main editor canvas, and a small animated inspector.

All three show the same images.

They can keep separate stages while sharing one runtime/cache.

## Put `GRuntimeProvider` above the views

```dart
class EditorState extends State<Editor> {
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
      child: const EditorBody(),
    );
  }
}
```

Any descendant `GraphXView` automatically discovers that runtime through Flutter inherited-widget lookup.

There is no extra parameter on every view.

## The stages remain independent

Sharing runtime does **not** merge scenes:

```text
              shared GRuntime
                    │
             shared GAssets
              ↙           ↘
        Stage A           Stage B
          │                 │
     node tree A       node tree B
```

Each stage keeps its own viewport, pointer state, focus, updates, root, and hierarchy.

Only runtime-level resources are shared.

This is why the same texture can be reused without one scene becoming responsible for another scene's nodes.

## Sharing pays off before the first frame is finished

Because `GAssets` deduplicates in-flight cached loads, two stages requesting the same texture at almost the same time can converge on the same read/decode rather than racing to decode it twice.

That makes shared runtime useful not only for long-term memory reuse but also during parallel scene startup.

## Keep a shared runtime stable

A `GraphXView` can observe that the nearest `GRuntimeProvider` changed and switch its stage to the new runtime for future runtime work.

But existing nodes may still hold textures/resources obtained from the previous runtime.

So ordinary app code should prefer a simpler rule: create the shared runtime at a stable application boundary and keep it there for the lifetime of the views that depend on it.

Runtime replacement is possible; it should be intentional.
