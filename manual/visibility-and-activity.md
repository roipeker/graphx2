# Visibility and activity

“Make it disappear” is underspecified in a retained scene.

Do you mean: stop painting it, stop hit testing it, pause its own update callback, or merely make its pixels transparent?

GraphX keeps those choices separate because they have different runtime consequences.

## Hide it

The most direct switch is `visible`:

```dart
overlay.visible = false;
```

The node and its visual branch stop rendering. They also stop participating in pointer hit testing and focus/semantics traversal while hidden.

The node is still in the scene tree. Its parent has not changed, its children are still attached, and you can show it again later:

```dart
overlay.visible = true;
```

The difference becomes more obvious when the hidden thing is an entire branch rather than one node.

A scene hierarchy can get fairly deep. An editor overlay may contain guides, handles, labels, effects, and nested groups below it. If that whole branch is temporarily disabled, setting the parent to `visible = false` lets GraphX skip rendering and pointer hit testing for the branch without tearing the hierarchy apart.

That can avoid a lot of unnecessary per-frame work, and it is usually much simpler than removing a subtree and adding it back again just because it needs to disappear for a while.

Use `visible` when the branch still belongs to the scene but should be absent from presentation/input for now—for example an editor overlay layer that is temporarily disabled.

## Visible, but not interactive

Sometimes you still want the branch on screen, but you do not want it participating in pointer hit testing.

That is a different switch:

```dart
overlay.pointer.enabled = false;
```

The node can still render normally; its pointer participation is disabled.

We will explore pointer control properly in the input chapters. For now, it is enough to know that you do not need to hide something just to make it ignore the pointer.

## Make it inactive

`active` is the stronger participation switch:

```dart
overlay.active = false;
```

An inactive node is skipped by rendering and input/focus participation, and if that node has its own update callback enabled, GraphX removes that updater until the node becomes active again.

```dart
overlay.active = true;
```

Use `active = false` when the object should stop participating as a live scene object, not merely disappear visually.

The update callback may feel early here; [Frame updates](#frame-updates) explains the loop in detail. The distinction here is that `active` reaches further than `visible`.

One subtle point: child update callbacks are registered independently. Making a parent inactive hides its rendered/input branch, but it does not silently rewrite every child's `active` property for you.

## Transparent is still there

Alpha is different again:

```dart
overlay.alpha = 0.0;
```

Now the branch is fully transparent, but the node has not been hidden or deactivated.

That matters for input. A transparent interactive node can still receive pointer events because hit testing is controlled by the scene/input state rather than by how many pixels happen to be visible.

Flutter has the same conceptual split. `Opacity(opacity: 0)` changes painting, while `IgnorePointer` changes hit testing; they are different widgets because they answer different questions. GraphX exposes those decisions as retained node/input properties instead of wrapper widgets.

There is another alpha detail worth separating from visibility. Normal inherited alpha and applying opacity to a whole composited subtree are not always visually equivalent, especially when children overlap. [Alpha and blending](#alpha-and-blending) shows why GraphX sometimes isolates a branch into a layer and what that costs.

If you mean "the user should not be able to interact with this," `visible` or `pointer.enabled = false` is clearer than relying on `alpha = 0`.

## Choose the switch that matches the intent

Think of the three controls like this:

- `alpha` — how strongly should this be painted?
- `visible` — should this branch be presented at all?
- `active` — should this node participate as an active scene object?

They overlap visually, but they express different intent.

Keeping that distinction tends to make scene code easier to read later, especially when animation, focus, portals, and input start sharing the same hierarchy.
