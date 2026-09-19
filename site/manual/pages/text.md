# Text

Text in GraphX is a scene object too.

You can place it, rotate it, scale it, group it with other nodes, and measure it without turning it into a Flutter widget.

## `GText` is retained paragraph text

```dart
final label = root.addChild(
  GText(
    'Hello GraphX',
    style: const TextStyle(
      fontSize: 28,
      color: Colors.white,
    ),
  ),
);

label.setPosition(40, 60);
```

If that `TextStyle` looks familiar, it should.

`GTextStyle` is an alias for Flutter's `TextStyle`, so the typography knowledge you already have from Flutter carries over directly.

This works too:

```dart
const style = GTextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: Colors.blue,
);
```

There is no separate GraphX font-style language to learn.

## Not a Flutter `Text` widget

`GText` does not participate in Flutter widget layout.

It is a retained GraphX node backed directly by a `dart:ui.Paragraph`. GraphX builds and lays out that paragraph when the text or relevant style changes, then keeps the result around for painting.

That gives us a useful combination:

- Flutter's text shaping and paragraph engine;
- GraphX transforms and scene hierarchy;
- retained layout rather than rebuilding a `Text` widget for every scene update.

So the relationship is roughly:

```text
TextStyle + string  →  ui.Paragraph  →  GText node
```

Flutter still does the hard text shaping. GraphX gives the paragraph a persistent place in the scene.

## A text object is still a node

There is one architectural detail worth noticing here: `GText` is not a leaf renderable attached to some separate scene node. It **is** a `GNode`.

The same is true of `GImage`, `GShape`, and the other built-in visuals. They inherit the normal node transform, lifecycle, input, visibility, and child hierarchy instead of living beside it as a separate render component.

That means even a text node can have children:

```dart
final label = root.addChild(
  GText(
    'LIVE',
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),
);

final dot = label.addChild(GShape());
dot.graphics
    .beginFill(Colors.red)
    .drawCircle(0, 0, 4)
    .endFill();

dot.setPosition(
  label.textWidth + 8,
  label.textHeight * 0.5,
);
```

Move, rotate, fade, or hide `label` and the dot follows because it is genuinely part of that node's subtree.

GraphX² originally explored a more separated model where a node could own a distinct view/renderable component. The final API stayed closer to the GraphX1/display-list inheritance idea: visual types extend the scene node directly.

There is one GraphX² twist to that lineage. In classic Flash, not every display object was a container. In GraphX², ordinary visual nodes inherit the container-capable `GNode` API, so an image or text node can still own descendants when that relationship is useful. Specialized node types may deliberately restrict children when they bridge to a different hierarchy.

We will use that same idea in [Custom nodes](#custom-nodes), where a normal `GNode` becomes a new renderable type without creating a second hierarchy.

## Natural width or a text box

By default, text uses its natural width:

```dart
final title = GText(
  'GraphX retained text',
  style: const TextStyle(fontSize: 24),
);
```

If you provide `maxWidth`, the paragraph lays out inside that width and can wrap:

```dart
final description = GText(
  'This sentence can wrap onto more than one line.',
  maxWidth: 220,
  style: const TextStyle(fontSize: 16),
);
```

This is not a Flutter `SizedBox` or `Expanded`; there is still no widget-style layout negotiation happening. `maxWidth` is simply a constraint passed to the retained paragraph itself.

That distinction fits the same scene-vs-layout model we introduced earlier.

## Measuring text

Sometimes the next object depends on how large the text actually became.

`GText` exposes both text metrics and the paragraph layout box:

```dart
print(label.textWidth);
print(label.textHeight);
print(label.layoutWidth);
print(label.layoutHeight);
```

For unconstrained text, `layoutWidth` is usually the natural paragraph width.

When `maxWidth` is finite, `layoutWidth` is that requested layout width even when the longest visible line is shorter. `textWidth` reports the longest rendered line instead.

That distinction becomes useful when aligning labels, drawing backgrounds behind text, or building your own small scene-layout helpers.

## Alignment, lines, and ellipsis

The common paragraph controls are available directly:

```dart
final caption = GText(
  'A longer caption that may not fit.',
  maxWidth: 160,
  align: TextAlign.center,
  maxLines: 2,
  ellipsis: '…',
  style: const TextStyle(fontSize: 14),
);
```

You can also inspect the result:

```dart
print(caption.lineCount);
print(caption.didExceedMaxLines);
```

That makes it possible to react to actual laid-out text instead of guessing from character counts.

## Change it later

Because `GText` is retained, changing the string updates the same node:

```dart
score.text = 'Score: 1200';
```

Likewise, a style change updates the retained paragraph when necessary:

```dart
score.color = Colors.amber;
```

GraphX keeps paragraph construction and paragraph layout invalidation separate internally, so changes only rebuild the parts of retained text state that need to change.

You do not need to manage that invalidation yourself.

## Rich text

When one paragraph needs more than one style, use `GText.rich()` with runs:

```dart
final stats = GText.rich(
  const [
    GTextRun('GPU '),
    GTextRun(
      '2.8 ms',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.green,
      ),
    ),
  ],
  style: const TextStyle(
    fontSize: 16,
    color: Colors.white,
  ),
);
```

The base style applies to the paragraph, and each run can override only the pieces it needs.

If later you assign plain `text`, the node leaves rich-text mode and becomes an ordinary single-style `GText` again.

## Text still belongs to the scene

Paragraph layout and scene placement are separate concerns.

`GText` figures out the geometry of its text. GraphX then places that geometry through the same node transform system used by everything else:

```dart
label.alignPivot(0, 0);
label.setPosition(200, 120);
label.rotation = 0.1;
```

That is what makes text useful in labels, diagrams, games, HUDs, editors, animated interfaces, and other places where the words need to behave like part of a visual scene rather than a rectangular Flutter layout tree.
