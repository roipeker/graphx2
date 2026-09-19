# GRuntime

A stage is one scene world. A runtime is the small piece of GraphX state that can sensibly live **longer than one stage**.

Today that distinction is intentionally modest.

## The runtime owns shared resources

Every stage has:

```dart
stage.runtime
```

and the runtime currently owns the shared asset store:

```dart
stage.runtime.assets
```

which is also exposed as the shorter:

```dart
stage.assets
```

A default `GraphXView` creates a stage with its own runtime. Dispose that stage and its owned runtime/resources go away with it.

That is a good default because a scene does not accidentally keep resources alive forever.

## Runtime is not another scene graph

`GRuntime` does not own nodes, transforms, pointer routing, or viewport state.

Those belong to `GStage` and the retained node hierarchy.

The split is:

```text
GRuntime
  shared/lifetime resources

GStage
  viewport, input, timing, environment

GNode tree
  visual scene
```

Keeping runtime deliberately small prevents “global engine context” from becoming a dumping ground for unrelated state.

## Custom URL transport also belongs here

Because URL transport policy can be shared across many scenes, the runtime constructor accepts it:

```dart
final runtime = GRuntime(
  urlLoader: loadBytesForMyApp,
);
```

That gives every stage using this runtime the same remote-asset transport policy without teaching scene nodes about authentication/network clients.

## Own the lifetime you create

When a stage creates its own default runtime, the stage disposes it.

When application code creates a shared runtime:

```dart
final runtime = GRuntime();
```

application code owns it and must eventually call:

```dart
runtime.dispose();
```

That ownership rule is boring in the best possible way: the thing that creates the long-lived shared runtime is responsible for ending its lifetime.

The next chapter shows the Flutter mechanism for making that one runtime available to several GraphX views.
