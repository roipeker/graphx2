# Portals

Sometimes the right way to render something in a GraphX scene is… not to render it with GraphX.

A text field, platform view, native Flutter control, or complicated widget tree already has a renderer, semantics, focus behavior, and layout system. Rebuilding all of that as canvas pixels would be the wrong fight.

A portal lets a Flutter widget live at a GraphX node position.

## Put a real Flutter widget in the scene

```dart
final field = root.addChild(
  GPortal<void>(
    child: const TextField(
      decoration: InputDecoration(
        hintText: 'Your name',
      ),
    ),
    width: 240,
    height: 56,
  ),
);

field.setPosition(80, 120);
```

The `TextField` remains a real Flutter widget. GraphX provides its scene transform and placement.

Move or rotate the portal node and the Flutter subtree follows the GraphX transform. Parent transforms are included too.

Inherited GraphX `alpha`, `visible`, and `active` state are reflected into the Flutter presentation, so fading/hiding a parent branch also affects the portal.

## Front or behind the GraphX canvas

A portal can be hosted in front of the GraphX surface:

```dart
placement: GPortalPlacement.front
```

or behind it:

```dart
placement: GPortalPlacement.behind
```

That gives you two useful composition planes around the GraphX canvas without pretending arbitrary Flutter widgets can be interleaved between every individual canvas draw call.

A front portal is natural for form controls and overlays. A behind portal can be useful for Flutter-rendered content that GraphX should draw over.

## Portal input stays Flutter input

By default the Flutter subtree receives pointer interaction:

```dart
portal.pointerEnabled = true;
```

Disable it without hiding the widget:

```dart
portal.pointerEnabled = false;
```

Flutter hit testing then ignores the portal content while GraphX can continue rendering around it.

Portal focus also integrates with the GraphX focus boundary, so traversal can enter the Flutter controls inside a portal and later return to GraphX scene focus instead of creating two unrelated keyboard worlds.

## Static child or retained builder

A portal can hold one widget directly:

```dart
GPortal<void>(
  child: const Text('Flutter'),
)
```

Or keep a typed value and rebuild its Flutter content deliberately:

```dart
final counter = GPortal<int>.builder(
  value: 0,
  builder: (context, value) {
    return Text('Count: $value');
  },
);
```

Update the value later:

```dart
counter.value = 12;
```

The Flutter content rebuild is explicit; ordinary GraphX transform/alpha/visibility changes update the lightweight portal presentation without rebuilding the widget subtree.

That separation matters when a portal is moving every frame.

## Flutter decides the widget's layout size

A portal has a GraphX-visible `layoutSize` after Flutter lays out its content:

```dart
print(portal.layoutSize.width);
print(portal.layoutSize.height);
```

You can provide width/height constraints directly, or let Flutter resolve them when the widget can size itself.

When the resolved size changes, `onLayoutSizeChanged` notifies the GraphX side.

The portal's own bounds follow that Flutter layout size, so the scene has real geometry for transforms and hit inspection rather than guessing the widget dimensions.

## A portal is deliberately a leaf in the GraphX tree

Most GraphX visual nodes such as `GText`, `GImage`, and `GShape` inherit the normal child-container API from `GNode`.

`GPortal` is a deliberate exception:

```dart
portal.addChild(otherNode); // unsupported
```

The reason is structural rather than arbitrary. Its descendants are a **Flutter widget subtree**, not GraphX renderable children.

Put GraphX siblings/children on the portal's parent, and put Flutter widgets inside the portal child/builder. Keeping that boundary explicit prevents two hierarchies from pretending to be one.

## Snapshot a portal when pixels are what you need

Sometimes a real widget is useful while editing, but later you want its rendered pixels as a GraphX texture:

```dart
final texture = await portal.snapshot();
```

There is also `snapshotSync()` for already-painted repaint-boundary portals when the synchronous preconditions are satisfied.

The result is an owned `GTexture`, so normal texture ownership rules apply.

Snapshotting is not the default portal rendering path; it is an explicit bridge when you intentionally want to turn Flutter output into pixels.

## Portals are the treaty between two layout worlds

Earlier we said:

> Flutter lays out the application. GraphX handles the scene inside the space Flutter gave it.

A portal is the interesting exception where the two meet locally.

GraphX says **where this retained scene object is**. Flutter says **how this widget subtree lays itself out and behaves**.

Neither system needs to impersonate the other.
