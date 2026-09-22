// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  group('GSignal dispatch contract', () {
    test('listeners run in registration order', () {
      final signal = GSignal<int>();
      final log = <String>[];

      signal.add((_) => log.add('first'));
      signal.add((_) => log.add('second'));

      signal.emit(0);

      expect(log, ['first', 'second']);
    });

    test('self-cancel and removing another listener take effect immediately', () {
      final signal = GSignal<int>();
      final log = <String>[];

      late GSignalSubscription firstSubscription;
      void second(int _) => log.add('second');

      firstSubscription = signal.add((_) {
        log.add('first');
        firstSubscription.cancel();
        signal.remove(second);
        signal.add((_) => log.add('deferred'));
      });
      signal.add(second);

      signal.emit(0);
      expect(log, ['first']);
      expect(firstSubscription.isActive, isFalse);

      signal.emit(0);
      expect(log, ['first', 'deferred']);
    });

    test('keyed removal during dispatch skips matching pending listeners', () {
      final signal = GSignal<int>();
      final key = Object();
      final log = <String>[];

      signal.add((_) {
        log.add('remove');
        expect(signal.removeKey(key), 2);
      });
      signal.add((_) => log.add('keyed-a'), key: key);
      signal.add((_) => log.add('keyed-b'), key: key);
      signal.add((_) => log.add('tail'));

      signal.emit(0);

      expect(log, ['remove', 'tail']);
      expect(signal.containsKey(key), isFalse);
    });

    test('removeAll during dispatch skips all pending listeners', () {
      final signal = GSignal<int>();
      final log = <String>[];

      signal.add((_) {
        log.add('first');
        signal.removeAll();
      });
      signal.add((_) => log.add('second'));

      signal.emit(0);

      expect(log, ['first']);
      expect(signal.listenerCount, 0);
      expect(signal.hasListeners, isFalse);
    });

    test('nested emit has its own deterministic dispatch boundary', () {
      final signal = GSignal<int>();
      final log = <String>[];
      var nested = false;

      signal.add((value) {
        log.add('a$value');
        if (!nested) {
          nested = true;
          signal.emit(1);
        }
      });
      signal.add((value) => log.add('b$value'));

      signal.emit(0);

      expect(log, ['a0', 'a1', 'b1', 'b0']);
    });

    test('once listeners are cancelled before reentrant invocation', () {
      final signal = GSignal<int>();
      var onceCalls = 0;

      final subscription = signal.once((_) {
        onceCalls++;
        signal.emit(1);
      });

      signal.emit(0);
      expect(onceCalls, 1);
      expect(subscription.isActive, isFalse);

      signal.emit(0);
      expect(onceCalls, 1);
    });

    test('cancellation is idempotent and activity state stays correct', () {
      final signal = GSignal<int>();
      var calls = 0;
      final subscription = signal.add((_) => calls++);

      expect(subscription.isActive, isTrue);
      expect(signal.listenerCount, 1);

      subscription.cancel();
      subscription.cancel();

      expect(subscription.isActive, isFalse);
      expect(signal.listenerCount, 0);

      signal.emit(0);
      expect(calls, 0);
    });

    test('subscription dispose cancels once and records disposal', () {
      final signal = GSignal<int>();
      final subscription = signal.add((_) {});

      subscription.dispose();
      subscription.dispose();

      expect(subscription.isActive, isFalse);
      expect(subscription.isDisposed, isTrue);
      expect(signal.listenerCount, 0);
    });

    test('signal disposal during dispatch is immediate and permanent', () {
      final signal = GSignal<int>();
      final log = <String>[];
      signal.add((_) {
        log.add('first');
        signal.dispose();
      });
      signal.add((_) => log.add('second'));

      signal.emit(0);

      expect(log, ['first']);
      expect(signal.isDisposed, isTrue);
      expect(signal.listenerCount, 0);
      expect(() => signal.add((_) {}), throwsStateError);

      signal.emit(1);
      expect(log, ['first']);
    });

    test('listener exceptions propagate and dispatch state remains valid', () {
      final signal = GSignal<int>();
      var tailCalls = 0;

      final throwing = signal.add((_) {
        throw StateError('expected');
      });
      signal.add((_) => tailCalls++);

      expect(() => signal.emit(0), throwsStateError);
      expect(tailCalls, 0);

      throwing.cancel();
      signal.emit(1);
      expect(tailCalls, 1);
    });

    test('duplicate keys are removed deterministically as one group', () {
      final signal = GSignal<int>();
      final key = Object();

      signal.add((_) {}, key: key);
      signal.add((_) {}, key: key);
      signal.add((_) {});
      expect(signal.removeKey(key), 2);
      expect(signal.removeKey(key), 0);
      expect(signal.listenerCount, 1);
    });
  });

  group('GSignal0 dispatch contract', () {
    test('add during dispatch is deferred and removal is immediate', () {
      final signal = GSignal0();
      final log = <String>[];

      void second() => log.add('second');
      signal.add(() {
        log.add('first');
        signal.remove(second);
        signal.add(() => log.add('deferred'));
      });
      signal.add(second);

      signal.emit();
      expect(log, ['first']);

      signal.emit();
      expect(log, ['first', 'first', 'deferred']);
    });

    test('once listener cannot fire twice through nested emit', () {
      final signal = GSignal0();
      var onceCalls = 0;

      final subscription = signal.once(() {
        onceCalls++;
        signal.emit();
      });

      signal.emit();

      expect(onceCalls, 1);
      expect(subscription.isActive, isFalse);
    });
    test('dispose releases listeners and future add fails', () {
      final signal = GSignal0();
      final subscription = signal.add(() {});

      signal.dispose();

      expect(signal.isDisposed, isTrue);
      expect(signal.listenerCount, 0);
      expect(subscription.isActive, isFalse);
      expect(() => signal.add(() {}), throwsStateError);

      signal.emit();
    });
  });
}
