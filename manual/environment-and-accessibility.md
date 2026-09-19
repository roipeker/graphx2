# Environment and accessibility

A retained scene lives longer than a Flutter build method, but it still lives inside a real application.

Dark mode can change. Text scaling can change. Screen readers need meaning, not pixels.

GraphX has bridges for those host concerns without turning every node into a widget.

## Read only the environment your scene cares about

The stage exposes a lazy environment:

```dart
final dark = stage.environment.dark;
final textScaler = stage.environment.textScaler;
```

Reading a property opts the stage into tracking that host value. If the scene never reads text scaling, GraphX does not create a `MediaQuery` dependency for text scaling just in case.

That keeps host synchronization demand-driven.

## Roots can react to consumed environment changes

```dart
class Scene extends GRoot {
  @override
  void attached() {
    applyTheme(stage.environment.dark);
  }

  @override
  void environmentChanged(GEnvironmentChange change) {
    if (change.brightness) {
      applyTheme(stage.environment.dark);
    }

    if (change.textScaler) {
      relayoutLabels(stage.environment.textScaler);
    }
  }

  void applyTheme(bool dark) {}

  void relayoutLabels(TextScaler scaler) {}
}
```

Only aspects the stage consumed are synchronized.

Callback scenes can listen to the corresponding `root.onEnvironment` / `stage.signals.onEnvironment` signal instead of overriding a method.

## Pixels are not accessibility

A beautiful custom button drawn with `GGraphics` is still just pixels to a screen reader until you annotate it.

GraphX semantics attach meaning to the same retained node:

```dart
final button = root.addChild(GShape());
final semantics = button.semantics;

semantics.role = GSemanticsRole.button;
semantics.label = 'Play';
semantics.action(GActions.activate);
```

The semantic node follows the retained scene geometry; GraphX does not require a parallel widget for every accessible scene object.

## Accessibility actions reuse the same action system

The button can respond through the same logical action route used by focus/keyboard/gamepad input:

```dart
button.onAction.add((event) {
  if (event.action != GActions.activate) return;

  play();
  event.handle();
});
```

An accessibility bridge can dispatch `activate` directly to that node without stealing the user's logical keyboard focus.

That shared action vocabulary is important: “activate” remains the behavior whether it came from Enter, a TV remote, a gamepad, or accessibility.

## Roles and state can describe richer controls

GraphX currently provides roles such as:

```text
generic
text
button
image
toggle
checkbox
radio
slider
menu
menuItem
```

State can include values such as `enabled`, `selected`, `checked`, and `toggled`.

A slider can also expose increased/decreased values and actions:

```dart
final semantics = slider.semantics;
semantics.role = GSemanticsRole.slider;
semantics.label = 'Volume';
semantics.value = '50 percent';
semantics.action(GSemanticsActions.increment);
semantics.action(GSemanticsActions.decrement);
```

The point is not to replicate Flutter's entire semantics API. It is to give retained GraphX controls enough platform-neutral meaning to participate correctly in the host accessibility tree.

## Semantics are lazy too

Merely reading:

```dart
node.semantics
```

does not immediately register a semantic node.

Registration begins when the semantic state actually differs from its defaults—when you add a label, role, state, action, etc.

That follows the same design pattern as focus and environment: capabilities should cost something when a scene uses them, not because the engine happens to support them.

## Portals keep native Flutter semantics

A `GPortal` hosts a real Flutter subtree, so the widgets inside it keep their Flutter focus and semantics behavior.

That is another reason portals are the right choice for native controls: GraphX does not need to reverse-engineer the accessibility behavior of a `TextField` it never should have replaced in the first place.

The retained GraphX scene and the Flutter widget subtree can therefore meet in one accessible application without pretending they are the same rendering system.
