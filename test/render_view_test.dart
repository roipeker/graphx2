import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render mask combines with one bitwise overlap contract', () {
    final world = GRenderMask.bit(0);
    final actors = GRenderMask.bit(1);
    final hud = GRenderMask.bit(2);

    expect((world | actors).overlaps(world), isTrue);
    expect((world | actors).overlaps(hud), isFalse);
    expect(GRenderMask.none.isEmpty, isTrue);
    expect(GRenderMask.all.overlaps(hud), isTrue);
  });

  test(
    'render view maps world and Stage points without allocation requirement',
    () {
      final view = GRenderView(
        viewport: GRect(100, 20, 200, 100),
        transform: GMatrix2(2, 0, 0, 2, -20, -40),
      );
      final point = GPoint();

      view.worldToStageInto(20, 30, point);
      expect(point.x, closeTo(120, 1e-9));
      expect(point.y, closeTo(40, 1e-9));

      expect(view.stageToWorldInto(point.x, point.y, point), isTrue);
      expect(point.x, closeTo(20, 1e-9));
      expect(point.y, closeTo(30, 1e-9));
    },
  );

  test('explicit views render the same retained Stage once per view', () async {
    final counter = _CountingNode();
    final root = GRoot()..addChild(counter);
    final stage = GStage(root)
      ..mount()
      ..setViewport(100, 100);
    stage.renderViews
      ..add(GRenderView(viewport: GRect(0, 0, 50, 100)))
      ..add(GRenderView(viewport: GRect(50, 0, 50, 100)));

    final session = GRenderSession(width: 100, height: 100);
    final texture = await session.renderStage(stage);

    expect(counter.paints, 2);
    texture.dispose();
    session.dispose();
    stage.dispose();
  });

  test('render groups reject complete subtrees per view mask', () async {
    final worldMask = GRenderMask.bit(0);
    final hudMask = GRenderMask.bit(1);
    final worldCounter = _CountingNode();
    final hudCounter = _CountingNode();
    final world = GRenderGroup(mask: worldMask)..addChild(worldCounter);
    final hud = GRenderGroup(mask: hudMask)..addChild(hudCounter);
    final root = GRoot()
      ..addChild(world)
      ..addChild(hud);
    final stage = GStage(root)
      ..mount()
      ..setViewport(100, 100);
    stage.renderViews
      ..add(GRenderView(viewport: GRect(0, 0, 50, 100), mask: worldMask))
      ..add(GRenderView(viewport: GRect(50, 0, 50, 100), mask: hudMask));

    final session = GRenderSession(width: 100, height: 100);
    final texture = await session.renderStage(stage);

    expect(worldCounter.paints, 1);
    expect(hudCounter.paints, 1);
    texture.dispose();
    session.dispose();
    stage.dispose();
  });

  test('Stage render views remain sparse until explicitly requested', () {
    final stage = GStage(GRoot())
      ..mount()
      ..setViewport(100, 100);

    expect(stage.hasRenderViews, isFalse);
    final views = stage.renderViews;
    expect(views.isEmpty, isTrue);
    expect(stage.hasRenderViews, isFalse);

    views.add(GRenderView(viewport: GRect(0, 0, 100, 100)));
    expect(stage.hasRenderViews, isTrue);
    stage.dispose();
  });
}

final class _CountingNode extends GNode {
  _CountingNode() {
    setPaintSelf(true);
  }

  int paints = 0;

  @override
  void paintSelf(GRenderContext context) {
    paints++;
  }
}
