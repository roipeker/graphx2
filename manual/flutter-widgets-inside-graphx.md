# Flutter widgets inside GraphX

A GraphX scene can live inside a Flutter application without forcing every visible thing onto the same renderer.

That matters most when something in the scene needs behavior Flutter already solves extremely well: text editing, IME composition, form controls, platform views, accessibility-heavy controls, or an existing widget you do not want to reimplement on Canvas.

`GPortal` is the bridge for those cases.

## A realistic example: rename something inside an editor

Imagine a node editor built in GraphX.

The scene already owns:

```text
zoomable/pannable world
connections and paths
selection outlines
nodes and handles
retained labels
hover / drag interaction
```

Most of that belongs comfortably in GraphX because it participates in one transformed scene.

Now the user double-clicks a node label to rename it.

At that moment you need:

```text
text selection
caret movement
IME composition
copy/paste
keyboard shortcuts
focus traversal
platform accessibility behavior
```

Reimplementing those behaviors inside a custom canvas text editor would add a large amount of complexity for no visual benefit.

Instead, temporarily place a real Flutter `TextField` at that GraphX position:

```dart
final editor = root.addChild(
  GPortal<void>(
    child: TextField(
      controller: controller,
      autofocus: true,
    ),
    width: 220,
    height: 48,
  ),
);

editor.setPosition(labelX, labelY);
```

The surrounding diagram remains GraphX. The editing surface remains Flutter.

When editing finishes, remove the portal and update the retained `GText` label.

That is a much more useful way to think about portals than “sometimes widgets can appear inside GraphX.”

## GraphX still owns where the portal lives

The portal is a GraphX node, so its placement follows the scene:

```dart
editor.setPosition(labelX, labelY);
editor.rotation = labelRotation;
editor.alpha = 0.9;
```

Parent transforms also propagate to it.

Pan or zoom the editor world and the Flutter control follows the same retained transform chain rather than needing a second positioning system in application code.

Visibility and activity state are reflected into the hosted widget presentation too.

Flutter, meanwhile, continues to own the widget subtree's layout, focus, semantics, painting, and native interaction behavior.

## Use the boundary according to behavior, not appearance

A useful rule is not:

```text
vector-looking thing → GraphX
UI-looking thing     → Flutter
```

Appearance is a poor boundary.

An icon may be a `GIcon`, a texture-backed `GImage`, an imported SVG through an ecosystem package, or part of a Flutter control. There is no reason to redraw an ordinary icon as custom `GShape` geometry merely because GraphX *can* draw paths.

A better question is:

> **Who already owns the behavior this object needs?**

Scene content usually fits GraphX when it needs things such as:

```text
continuous transforms inside the scene hierarchy
large retained visual populations
custom hit geometry
scene-space drag/zoom interaction
masks / filters / caches / compositing
frame-driven visual behavior
```

Flutter is usually the better owner when the object depends heavily on:

```text
widget layout
forms and text editing
IME/platform integration
native focus conventions
existing Flutter component behavior
platform views
```

That boundary can move during an interaction. A retained `GText` label can become a Flutter `TextField` only while it is being edited, then become `GText` again afterward.

## Assets should stay assets

An ordinary visual asset does not need to become procedural GraphX geometry to “belong” in a scene.

Use the representation that matches the source:

```text
icon font glyph        → GIcon
bitmap / atlas frame   → GImage
animated frames        → GAnimatedImage
procedural vector art  → GShape / GGraphics
Flutter control        → GPortal
```

SVG and other imported formats can be handled by ecosystem packages that translate or retain the source appropriately.

The important distinction is that **scene ownership does not imply hand-authoring every pixel with `GGraphics`.**

## A portal is not a screenshot of a widget

The hosted subtree stays alive as Flutter UI.

A `TextField` still has a caret. A menu can still respond to keyboard navigation. A custom Flutter widget can still rebuild from its own state.

GraphX is supplying placement in the scene, not converting the widget into dead pixels.

When pixels really are what you need, portals expose a separate snapshot bridge, covered in [Portals](#portals) and [Snapshots](#snapshots).

## Front and behind are deliberate composition planes

A portal can live in front of the GraphX canvas or behind it.

That is useful, but it does not pretend Flutter widgets can be interleaved between every individual Canvas draw call in the retained scene.

Think of the host composition as:

```text
behind portals
      ↓
GraphX canvas
      ↓
front portals
```

Inside the GraphX canvas, normal node ordering applies. Inside each portal, Flutter controls its own widget subtree.

Keeping those composition domains explicit is much easier to reason about than pretending two render trees are one tree.

## Do not use a portal when ordinary Flutter around the view is simpler

Not every Flutter control near a GraphX scene belongs *inside* it.

A toolbar that never moves with the scene is usually cleaner as ordinary Flutter outside `GraphXView`.

A form panel docked beside an editor canvas probably belongs to the surrounding Flutter layout.

Use a portal when the Flutter widget genuinely needs to occupy a position **inside GraphX scene space**.

That keeps portals special for the cases where the bridge buys something real.
