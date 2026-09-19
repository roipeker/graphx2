# GPoint or Offset?

Flutter already has `Offset`, `Size`, and `Rect`.

GraphX has `GPoint`, `GSize`, `GRect`, and `GBounds`.

That is not because GraphX needs different mathematics. The difference is mostly about **how the values live and get reused inside a retained engine**.

## Flutter geometry is excellent at API boundaries

Flutter's geometry types are immutable value objects:

```dart
const point = Offset(20, 40);
const size = Size(120, 80);
final rect = Rect.fromLTWH(10, 20, 120, 80);
```

That is a very pleasant model for widget/layout/painting APIs.

Pass an `Offset` to `Canvas.drawLine()`, receive a `Rect` from a Flutter API, combine them with operators, discard them when done.

GraphX uses those same types whenever it talks directly to Flutter Canvas/`dart:ui`.

## GraphX geometry is mutable on purpose

A retained engine repeatedly asks questions such as:

```text
where is this local point in stage space?
what are this node's bounds now?
copy these coordinates into an output object
reuse the same temporary next frame
```

So:

```dart
final point = GPoint();
point.set(20, 40);
```

is mutable.

The same object can be reused:

```dart
node.localToGlobalInto(
  0,
  0,
  point,
);
```

Next frame, GraphX can write new coordinates into that same `GPoint` instead of allocating a new `Offset`/point object every time.

That matters most in hot paths—hit testing, transforms, particle/editor tools, repeated geometry conversions—not in a one-off button callback.

## Allocating forms still exist when clarity wins

You do not need to preallocate everything:

```dart
final global = node.localToGlobal(0, 0);
```

That returns a convenient `GPoint`.

The `...Into()` variants exist when a caller already has reusable storage and wants to avoid churn:

```dart
final scratch = GPoint();

node.localToGlobalInto(
  localX,
  localY,
  scratch,
);
```

Use the form that makes sense for the code you are writing.

A couple of temporary allocations in setup code are not a moral failure.

## Crossing into Flutter is one property away

GraphX geometry exposes Flutter conversions:

```dart
final point = GPoint(20, 40);
final offset = point.offset;
```

`offset` is a new Flutter `Offset`.

The reverse direction is just as direct:

```dart
const offset = Offset(20, 40);
final point = offset.gpoint;
```

The same pattern exists for sizes and rectangles:

```dart
final flutterSize = gsize.size;
final graphxSize = flutterSize.gsize;

final flutterRect = grect.rect;
final graphxRect = flutterRect.grect;
```

So choosing a GraphX geometry type does not trap you in a separate geometry universe.

## Reuse storage when conversion happens repeatedly

If you already own a `GPoint`, copy an `Offset` into it:

```dart
final scratch = GPoint();

offset.copyInto(scratch);
```

or:

```dart
scratch.setFromOffset(offset);
```

Likewise:

```dart
flutterSize.copyInto(graphxSize);
flutterRect.copyInto(graphxRect);
```

and the reverse setters:

```dart
graphxSize.setFromSize(flutterSize);
graphxRect.setFromRect(flutterRect);
```

Those little APIs exist so extension/engine code can cross the Flutter boundary without being forced to allocate on every conversion.

## `GRect` and `GBounds` answer different questions

`GRect` stores:

```text
x, y, width, height
```

It behaves like a mutable rectangle value.

`GBounds` stores the two corners:

```text
x1, y1, x2, y2
```

That representation is convenient when repeatedly expanding/unioning bounds around transformed geometry.

Convert a `GBounds` to Flutter when a Canvas API wants a `Rect`:

```dart
final flutterRect = bounds.rect;
```

and back:

```dart
final bounds = flutterRect.gbounds;
```

An empty `GBounds` becomes `Rect.zero` when converted to Flutter because Flutter `Rect` has no equivalent retained “empty bounds” sentinel state.

## `Offset` can still be the clearer type in your code

Suppose you are writing a custom Canvas painter inside `GCanvasNode`:

```dart
context.canvas.drawLine(
  const Offset(0, 0),
  const Offset(100, 40),
  paint,
);
```

Use `Offset`. That is the native Canvas API and it reads perfectly.

Suppose you are repeatedly converting ten thousand local points through a retained transform into reusable buffers:

```dart
node.localToGlobalInto(x, y, scratch);
```

`GPoint` is the natural fit.

The question is not:

> which point type is the GraphX religion?

It is:

> which representation fits this lifetime/API boundary?

## Why not just make `GPoint` an alias for `Offset`?

Because mutability/output reuse is part of the GraphX geometry contract.

An immutable `Offset` cannot be filled in place by:

```dart
localToGlobalInto(...)
```

without replacing the object.

GraphX could force every engine geometry operation to create new immutable values, but that would trade away a useful low-allocation path just to reduce the number of type names.

The interop extensions give us the best of both styles instead.

## This also explains the plain `x` / `y` style

In [Vectors and distance](#vectors-and-distance), many examples use:

```dart
final dx = targetX - x;
final dy = targetY - y;
```

rather than wrapping every pair in `Offset` or `GPoint`.

That is the same principle again: use an object when the value needs identity/storage/API interoperability; use two scalars when two scalars make the math clearest.

GraphX does not require geometry objects merely to prove that a pair of numbers is “really” a vector.

That directness is part of what keeps creative-coding examples small.
