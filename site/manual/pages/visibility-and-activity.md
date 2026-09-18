# Visibility and activity

There are a few different ways for something to "not be there" on screen, and they do not all mean the same thing.

GraphX keeps the common cases separate so you can say what you actually mean.

## Hide it

The most direct switch is `visible`:

```dart
panel.visible = false;
```

The node and its visual branch stop rendering. They also stop participating in pointer hit testing and focus/semantics traversal while hidden.

The node is still in the scene tree. Its parent has not changed, its children are still attached, and you can show it again later:

```dart
panel.visible = true;
```

Use `visible` when the thing still exists; you simply do not want it presented or interacted with right now.

## Make it inactive

`active` is the stronger participation switch:

```dart
panel.active = false;
```

An inactive node is skipped by rendering and input/focus participation, and if that node has its own update callback enabled, GraphX removes that updater until the node becomes active again.

```dart
panel.active = true;
```

This is useful for scene objects that are temporarily out of play rather than merely hidden.

One subtle point: child update callbacks are registered independently. Making a parent inactive hides its rendered/input branch, but it does not silently rewrite every child's `active` property for you.

## Transparent is still there

Alpha is different again:

```dart
panel.alpha = 0.0;
```

Now the branch is fully transparent, but the node has not been hidden or deactivated.

That matters for input. A transparent interactive node can still receive pointer events because hit testing is controlled by the scene/input state rather than by how many pixels happen to be visible.

If you mean "the user should not be able to interact with this," `visible` or the appropriate input state is clearer than relying on `alpha = 0`.

## A useful rule of thumb

Think of the three controls like this:

- `alpha` — how strongly should this be painted?
- `visible` — should this branch be presented at all?
- `active` — should this node participate as an active scene object?

They overlap visually, but they express different intent.

Keeping that distinction tends to make scene code easier to read later, especially when animation, focus, portals, and input start sharing the same hierarchy.
