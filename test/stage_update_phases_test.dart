import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';
import 'package:graphx/graphx_extension.dart';

void main() {
  group('GStage update phases', () {
    test('node updaters run before update, postUpdate, and lateUpdate', () {
      final events = <String>[];
      final root = GRoot()..addChild(_OrderedUpdater(events));
      final stage = GStage(root)
        ..mount()
        ..setViewport(100, 100);

      stage.signals.onUpdate.add((_) => events.add('update'));
      stage.signals.onPostUpdate.add((_) => events.add('postUpdate'));
      stage.signals.onLateUpdate.add((_) => events.add('lateUpdate'));

      stage.tick(1 / 60);

      expect(events, ['updater', 'update', 'postUpdate', 'lateUpdate']);
      stage.dispose();
    });

    test('phase signals preserve add, remove, and once mutation semantics', () {
      for (var phase = 0; phase < 3; phase++) {
        final stage = GStage(GRoot())
          ..mount()
          ..setViewport(100, 100);
        final signal = _phaseSignal(stage, phase);
        final events = <String>[];
        late GSignalSubscription second;
        var added = false;

        signal.add((_) {
          events.add('first');
          second.cancel();
          if (!added) {
            added = true;
            signal.add((_) => events.add('added'));
          }
        });
        second = signal.add((_) => events.add('second'));
        signal.addOnce((_) => events.add('once'));

        stage.tick(1 / 60);
        expect(events, ['first', 'once']);

        events.clear();
        stage.tick(1 / 60);
        expect(events, ['first', 'added']);

        stage.dispose();
      }
    });

    test('each update phase alone keeps the Stage ticking and can sleep', () {
      for (var phase = 0; phase < 3; phase++) {
        final host = _TestHost();
        final stage = GStage(GRoot())
          ..mount()
          ..setViewport(100, 100);
        stage.attachHost(host);

        final subscription = _phaseSignal(stage, phase).add((_) {});
        expect(stage.hasContinuousUpdates, isTrue);
        expect(stage.wantsUpdate, isTrue);
        expect(host.tickRequests, 1);

        stage.handleFrame(Duration.zero);
        expect(host.tickRequests, 2);

        subscription.cancel();
        expect(stage.hasContinuousUpdates, isFalse);
        expect(stage.wantsUpdate, isFalse);

        stage.handleFrame(const Duration(milliseconds: 16));
        expect(host.tickRequests, 2);
        stage.dispose();
      }
    });

    test('Stage disposal tears down all update phases', () {
      final stage = GStage(GRoot())
        ..mount()
        ..setViewport(100, 100);
      final update = stage.signals.onUpdate;
      final post = stage.signals.onPostUpdate;
      final late = stage.signals.onLateUpdate;
      final subscriptions = [
        update.add((_) {}),
        post.add((_) {}),
        late.add((_) {}),
      ];

      stage.dispose();

      expect(update.isDisposed, isTrue);
      expect(post.isDisposed, isTrue);
      expect(late.isDisposed, isTrue);
      expect(stage.hasContinuousUpdates, isFalse);
      for (final subscription in subscriptions) {
        expect(subscription.isActive, isFalse);
      }
      expect(() => post.add((_) {}), throwsStateError);
      expect(() => late.add((_) {}), throwsStateError);
    });
  });
}

GSignal<double> _phaseSignal(GStage stage, int phase) {
  return switch (phase) {
    0 => stage.signals.onUpdate,
    1 => stage.signals.onPostUpdate,
    _ => stage.signals.onLateUpdate,
  };
}

final class _OrderedUpdater extends GNode {
  _OrderedUpdater(this.events) {
    updatesEnabled = true;
  }

  final List<String> events;

  @override
  void update(double delta) {
    events.add('updater');
  }
}

final class _TestHost implements GStageHost {
  int tickRequests = 0;

  @override
  void scheduleTick() {
    tickRequests++;
  }

  @override
  void schedulePaint() {}

  @override
  void updateCursor(GCursor cursor) {}
}
