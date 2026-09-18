import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets(
    'focus traverses outer Flutter, GraphX, portal Flutter, GraphX, outer Flutter',
    (tester) async {
      final outerBefore = FocusNode(debugLabel: 'outer-before');
      final portalFirst = FocusNode(debugLabel: 'portal-first');
      final portalSecond = FocusNode(debugLabel: 'portal-second');
      final outerAfter = FocusNode(debugLabel: 'outer-after');
      final controller = GraphxController<_PortalFocusRoot>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SizedBox(width: 240, child: TextField(focusNode: outerBefore)),
                SizedBox(
                  width: 320,
                  height: 220,
                  child: GraphxView(
                    controller: controller,
                    root: () => _PortalFocusRoot(portalFirst, portalSecond),
                  ),
                ),
                SizedBox(width: 240, child: TextField(focusNode: outerAfter)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final root = controller.root;

      outerBefore.requestFocus();
      await tester.pump();
      expect(outerBefore.hasPrimaryFocus, isTrue);

      await _tab(tester);
      expect(root.first.hasFocus, isTrue);
      expect(root.stage.focus.focusedNode, same(root.first));

      await _tab(tester);
      expect(root.portal.hasFocus, isTrue);
      expect(root.stage.focus.focusedNode, same(root.portal));
      expect(portalFirst.hasPrimaryFocus, isTrue);

      await _tab(tester);
      expect(root.portal.hasFocus, isTrue);
      expect(portalSecond.hasPrimaryFocus, isTrue);

      await _tab(tester);
      expect(root.last.hasFocus, isTrue);
      expect(root.stage.focus.focusedNode, same(root.last));

      await _tab(tester);
      expect(outerAfter.hasPrimaryFocus, isTrue);
      expect(root.stage.focus.focusedNode, isNull);

      await _shiftTab(tester);
      expect(root.last.hasFocus, isTrue);

      await _shiftTab(tester);
      expect(root.portal.hasFocus, isTrue);
      expect(FocusManager.instance.primaryFocus, same(portalSecond));

      await _shiftTab(tester);
      expect(root.portal.hasFocus, isTrue);
      expect(portalFirst.hasPrimaryFocus, isTrue);

      await _shiftTab(tester);
      expect(root.first.hasFocus, isTrue);

      await _shiftTab(tester);
      expect(outerBefore.hasPrimaryFocus, isTrue);
      expect(root.stage.focus.focusedNode, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      outerBefore.dispose();
      portalFirst.dispose();
      portalSecond.dispose();
      outerAfter.dispose();
    },
  );

  testWidgets(
    'programmatic traversal visits portal Flutter buttons before leaving',
    (tester) async {
      final portalFirst = FocusNode(debugLabel: 'portal-button-first');
      final portalSecond = FocusNode(debugLabel: 'portal-button-second');
      final controller = GraphxController<_PortalButtonFocusRoot>();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 420,
            height: 240,
            child: GraphxView(
              controller: controller,
              root: () => _PortalButtonFocusRoot(portalFirst, portalSecond),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final root = controller.root;
      expect(root.first.requestFocus(), isTrue);
      await tester.pump();
      expect(root.first.hasFocus, isTrue);

      expect(root.stage.focus.next(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(root.portal.hasFocus, isTrue);
      expect(portalFirst.hasPrimaryFocus, isTrue);

      expect(FocusManager.instance.primaryFocus!.nextFocus(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(root.portal.hasFocus, isTrue);
      expect(portalSecond.hasPrimaryFocus, isTrue);

      expect(FocusManager.instance.primaryFocus!.nextFocus(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(root.last.hasFocus, isTrue);
      expect(root.stage.focus.focusedNode, same(root.last));

      expect(root.stage.focus.previous(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(root.portal.hasFocus, isTrue);
      expect(portalSecond.hasPrimaryFocus, isTrue);

      expect(FocusManager.instance.primaryFocus!.previousFocus(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(root.portal.hasFocus, isTrue);
      expect(portalFirst.hasPrimaryFocus, isTrue);

      expect(FocusManager.instance.primaryFocus!.previousFocus(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(root.first.hasFocus, isTrue);
      expect(root.stage.focus.focusedNode, same(root.first));

      await tester.pumpWidget(const SizedBox.shrink());
      portalFirst.dispose();
      portalSecond.dispose();
    },
  );

  testWidgets('portal child keeps raw keyboard ownership while focused', (
    tester,
  ) async {
    final portalFirst = FocusNode(debugLabel: 'portal-first');
    final portalSecond = FocusNode(debugLabel: 'portal-second');
    final controller = GraphxController<_PortalFocusRoot>();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 220,
          child: GraphxView(
            controller: controller,
            root: () => _PortalFocusRoot(portalFirst, portalSecond),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final root = controller.root;
    var rawDown = 0;
    root.stage.input.keyboard.onDown.add((_) => rawDown++);

    root.portal.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(root.stage.focus.focusedNode, same(root.portal));
    expect(portalFirst.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(rawDown, 0);
    expect(root.stage.focus.focusedNode, same(root.portal));
    expect(portalFirst.hasPrimaryFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    portalFirst.dispose();
    portalSecond.dispose();
  });

  testWidgets('GraphxView autofocus adopts first logical GraphX focus', (
    tester,
  ) async {
    final portalFirst = FocusNode(debugLabel: 'portal-first');
    final portalSecond = FocusNode(debugLabel: 'portal-second');
    final controller = GraphxController<_PortalFocusRoot>();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 220,
          child: GraphxView(
            controller: controller,
            config: const GraphxConfig(autofocus: true),
            root: () => _PortalFocusRoot(portalFirst, portalSecond),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final root = controller.root;
    expect(root.stage.focus.focusedNode, same(root.first));
    expect(root.first.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    portalFirst.dispose();
    portalSecond.dispose();
  });
}

Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  await tester.pump();
}

Future<void> _shiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
  await tester.pump();
}

final class _PortalFocusRoot extends GRoot {
  _PortalFocusRoot(this.portalFirst, this.portalSecond) {
    first = addChild(_FocusBox('first')..focusable = true);
    portal = addChild(
      GPortal<void>(
        width: 240,
        height: 120,
        child: Material(
          child: Column(
            children: <Widget>[
              TextField(focusNode: portalFirst),
              TextField(focusNode: portalSecond),
            ],
          ),
        ),
      )..setPosition(40, 40),
    );
    last = addChild(
      _FocusBox('last')
        ..focusable = true
        ..setPosition(40, 180),
    );
  }

  final FocusNode portalFirst;
  final FocusNode portalSecond;
  late final GNode first;
  late final GPortal<void> portal;
  late final GNode last;
}

final class _PortalButtonFocusRoot extends GRoot {
  _PortalButtonFocusRoot(this.portalFirst, this.portalSecond) {
    first = addChild(_FocusBox('first')..focusable = true);
    portal = addChild(
      GPortal<void>(
        width: 260,
        height: 100,
        child: Material(
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  focusNode: portalFirst,
                  onPressed: () {},
                  child: const Text('A'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  focusNode: portalSecond,
                  onPressed: () {},
                  child: const Text('B'),
                ),
              ),
            ],
          ),
        ),
      )..setPosition(40, 40),
    );
    last = addChild(
      _FocusBox('last')
        ..focusable = true
        ..setPosition(40, 180),
    );
  }

  final FocusNode portalFirst;
  final FocusNode portalSecond;
  late final GNode first;
  late final GPortal<void> portal;
  late final GNode last;
}

final class _FocusBox extends GNode {
  _FocusBox(String name) : super(name);

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, 40, 40);
}
