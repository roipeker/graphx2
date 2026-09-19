# Icons and defaults

A tiny icon is still a real scene object.

It can rotate with a toolbar, fade with a panel, inherit a color from its parent scope, receive a larger hit area than its glyph, or become part of a composite control.

That is what `GIcon` is for.

## Use the Flutter icon data you already know

```dart
final heart = root.addChild(
  GIcon(
    Icons.favorite,
    size: 28,
    color: Colors.red,
  ),
);

heart.setPosition(40, 40);
```

`GIcon` accepts Flutter `IconData`, so Material/icon-font knowledge carries over directly.

It is not a Flutter `Icon` widget embedded in the scene. GraphX retains the glyph as a node and paints it through Flutter's text/icon backend.

That gives it normal GraphX behavior:

```dart
heart.rotation = GMath.radians(12);
heart.alpha = 0.8;
heart.scale = 1.2;
```

## The icon owns a predictable square box

A `GIcon` with size `28` has a `28 × 28` local layout/bounds box.

The actual glyph ink may occupy less of that square, because fonts have their own metrics, but scene geometry stays deterministic.

That is useful when placing icons beside labels or building controls:

```dart
icon.setPosition(0, 0);
label.setPosition(icon.size + 10, 3);
```

And if the touch target should be larger than that box, the hit area can still extend beyond it just like we saw in [Hover and capture](#hover-and-capture).

## Raw glyphs work too

When you have a code point/font rather than Flutter `IconData`:

```dart
final icon = GIcon.glyph(
  0xe001,
  fontFamily: 'MyIcons',
  size: 24,
  color: Colors.white,
);
```

That keeps custom icon fonts in the same retained node model.

## A small subtree often wants shared defaults

Imagine a HUD with twelve labels and icons.

Repeating the same style on every object is noisy:

```dart
GText('Score', style: hudStyle);
GText('Lives', style: hudStyle);
GIcon(Icons.favorite, size: 18, color: Colors.white);
```

`GDefaults` creates a transparent retained scope:

```dart
final hud = root.addChild(
  GDefaults(
    textStyle: const TextStyle(
      fontSize: 16,
      color: Colors.white,
    ),
    iconStyle: const GIconStyle(
      size: 18,
      color: Colors.white,
    ),
  ),
);
```

Descendant `GText` and `GIcon` nodes can inherit the missing pieces:

```dart
hud.addChild(GText('Score'));
hud.addChild(GIcon(Icons.star));
```

A local value still wins when one child needs to differ:

```dart
hud.addChild(
  GIcon(
    Icons.warning,
    color: Colors.orange,
  ),
);
```

The inherited size remains `18`; only color is overridden.

## Defaults follow the scene tree

This is not a global singleton theme.

```text
root
├── lightPanel: GDefaults
│   └── text/icons
└── darkPanel: GDefaults
    └── text/icons
```

Each branch can resolve its own defaults naturally from its ancestors.

Nested `GDefaults` scopes merge too, so a deeper branch can change one piece while inheriting the rest.

Reparent a text/icon under another defaults scope and GraphX invalidates the inherited style resolution so the visual follows its new ancestry.

## Text scaling can be scoped too

`GDefaults` can also provide a Flutter `TextScaler`:

```dart
final accessiblePanel = GDefaults(
  textScaler: const TextScaler.linear(1.2),
);
```

Descendant `GText` nodes use that scaler when building their retained paragraphs.

This is separate from the host environment's text scale. Your application can read `stage.environment.textScaler` and choose how/where to feed that value into retained defaults when accessibility policy calls for it.

## Why not just put defaults on `GNode`?

Most nodes do not need text/icon styling state.

Keeping defaults in a specialized transparent scope means ordinary `GNode` stays small, while UI-oriented branches can opt into inherited visual defaults when they actually need them.

Extension packages can also subclass `GDefaults` and add their own retained defaults to the same hierarchy instead of creating a parallel theme tree.

That fits a recurring GraphX pattern: add capability where it belongs, without making every node pay for it.
