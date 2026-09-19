# Flutter widgets inside GraphX

GraphX is excellent at retained scene objects. Flutter is excellent at widgets.

When you need a `TextField`, native control, or existing Flutter component inside a moving scene, use both rather than recreating one system in the other.

## `GPortal` is the bridge

```dart
final input = root.addChild(
  GPortal<void>(
    child: const TextField(),
    width: 220,
    height: 52,
  ),
);

input.setPosition(60, 90);
```

GraphX owns the node transform. Flutter owns the widget layout/rendering/semantics inside the portal.

Parent GraphX transforms, alpha, visibility, and activity are reflected into the portal presentation.

The complete portal API is covered in [Portals](#portals); this chapter is about when that bridge is the right architectural choice.

## Do not paint a widget because it happens to be visual

A settings panel full of switches and text fields is already a solved Flutter problem.

A particle system is already a solved GraphX problem.

A good mixed screen might therefore be:

```text
Flutter app chrome
├── toolbar
├── GraphXView
│   ├── scene graphics
│   ├── animated objects
│   └── GPortal<TextField>
└── Flutter bottom controls
```

There is no prize for maximizing the percentage rendered by one framework.

Use the boundary that makes behavior simplest.

## Portals are especially good for interaction-heavy native UI

A Flutter `TextField` already handles IME composition, text selection, accessibility, cursor behavior, platform shortcuts, and focus.

A portal lets all of that survive while the control still participates spatially in the GraphX scene.

Likewise, a complicated existing Flutter widget can be embedded without rasterizing it into a dead texture first.

## Use GraphX visuals when the thing behaves like scene content

A label that rotates with a spacecraft is naturally `GText`.

An editable text field placed on a diagram is naturally a Flutter `TextField` portal.

An icon made from vector paths is naturally `GShape`.

A full Flutter settings card floating above the canvas may be naturally a portal—or simply ordinary Flutter outside `GraphXView`.

The question is less “can GraphX render this?” and more:

> which system already owns the behavior I want?

That usually leads to the cleanest code.
