# Signals

A retained engine has events that several systems may want to observe at once: pointer input, resize, focus changes, frame updates, animation completion.

GraphX uses `GSignal` as a small **synchronous multicast** primitive for those events.

If you know Flash/AS3, it fills some of the territory of `EventDispatcher` without wrapping everything in one generic event type. If you know Dart streams, the big difference is timing: a `GSignal` is immediate and synchronous rather than an asynchronous stream abstraction.

## A signal can have several listeners

```dart
final signal = GSignal<int>();

signal.add((value) {
  print('first: $value');
});

signal.add((value) {
  print('second: $value');
});

signal.emit(42);
```

Both listeners run, in registration order.

That is the same pattern you have already used throughout the manual:

```dart
node.pointer.onTap.add((event) {
  // react to the tap
});
```

or:

```dart
stage.signals.onResize.add((size) {
  // react to the viewport
});
```

Those APIs are not special event systems. They are normal GraphX signals carrying different payload types.

## Emission is synchronous

When GraphX calls:

```dart
signal.emit(value);
```

listeners run before `emit()` returns.

There is no queue, microtask, or hidden async boundary.

That makes signal-driven scene code easy to reason about:

```text
emit
 ↓
listener A
 ↓
listener B
 ↓
return to caller
```

If a listener throws, the exception propagates normally.

Use `Future`/streams/isolate messaging when the work itself is asynchronous. `GSignal` is for the engine-style case where dispatch should happen now, in registration order, before the caller continues.

## The subscription is your exact removal handle

`add()` returns a `GSignalSubscription`:

```dart
final subscription = stage.signals.onResize.add((size) {
  layout(size);
});
```

Later:

```dart
subscription.cancel();
```

Cancellation is idempotent, so cancelling twice is harmless.

This is usually cleaner than trying to remember which closure instance was registered.

For lifecycle-owned subscriptions:

```dart
class Overlay extends GNode {
  GSignalSubscription? resizeSubscription;

  @override
  void attached() {
    resizeSubscription = stage.signals.onResize.add(_resize);
  }

  void _resize(GSize size) {
    // update retained layout
  }

  @override
  void detached() {
    resizeSubscription?.cancel();
    resizeSubscription = null;
  }
}
```

The subscription lifetime now clearly follows the node's attachment lifetime.

## Listen once when the event is truly one-shot

```dart
animation.onComplete.once(() {
  removeFromParent();
});
```

`addOnce()` is an alias if that reads better to you:

```dart
animation.onComplete.addOnce(() {
  removeFromParent();
});
```

The listener removes itself **before** invocation, so even a nested signal emission cannot accidentally fire that once-listener a second time.

## Listener changes during dispatch are predictable

Signals are often mutated from inside their own callbacks, so GraphX defines that behavior explicitly.

If a listener cancels another listener that has not run yet, the cancelled listener is skipped immediately.

If a listener adds a new listener while the signal is being emitted, the new one waits until the **next** emission.

That means this does not grow the current dispatch underneath your feet:

```dart
signal.add((value) {
  signal.add((next) {
    print('I start on the next emit');
  });
});
```

Nested `emit()` calls get their own dispatch boundary.

You rarely need to think about these rules, which is exactly why having clear rules matters.

## `GSignal0` carries no payload

Some events only mean “it happened.”

```dart
final closed = GSignal0();

closed.add(() {
  print('closed');
});

closed.emit();
```

GraphX uses `GSignal0` instead of inventing dummy `void` values or wrapper objects when there is nothing useful to carry.

Examples include lifecycle/dispose notifications and completion-style events.

## Keys can remove a related group of listeners

For systems that install several registrations under one owner, an optional key can group them:

```dart
final owner = Object();

signal.add(handleA, key: owner);
signal.add(handleB, key: owner);

signal.removeKey(owner);
```

The key uses object identity. It is mainly handy in infrastructure/package code; ordinary scene code is often clearer when it keeps the returned subscriptions directly.

## Listener count can switch work on and off

Signals also help GraphX keep optional systems demand-driven.

For example, stage update signals know when their listener count changes. Add an `onUpdate` listener and the stage knows continuous time is needed. Remove the last one and that reason to keep ticking disappears.

Pointer subsystems use the same general idea: if nobody is listening for a certain kind of interaction, there is no reason to eagerly maintain extra work for it.

That is one reason GraphX uses its own small signal primitive instead of treating every event as a generic stream: listener count, synchronous dispatch, exact cancellation, and mutation semantics are part of the engine's scheduling model.

## Signals complement overrides

A useful pattern has appeared several times in this manual:

```text
behavior belongs to my class
        → override a lifecycle/update method

behavior is composed from somewhere else
        → listen to a signal
```

For example, a `GRoot` subclass can override `resize()`. A helper object can listen to `stage.signals.onResize`.

Neither form is more “real” GraphX. They are two ways to attach behavior to the same retained runtime.
