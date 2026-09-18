// Copyright (c) 2026 GraphX by roipeker.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets(
    'GraphXView exposes retained semantics and routes accessibility actions',
    (tester) async {
      final handle = tester.ensureSemantics();
      final root = GRoot();
      final focused = root.addChild(
        _SemanticBox('focused')
          ..focusable = true
          ..x = 10
          ..y = 10,
      );
      focused.semantics
        ..label = 'Keyboard focus target'
        ..role = GSemanticsRole.button;

      var activations = 0;
      final button = root.addChild(
        _SemanticBox('button')
          ..x = 40
          ..y = 30,
      );
      button.semantics
        ..label = 'Launch'
        ..value = 'Ready'
        ..hint = 'Starts the demo'
        ..role = GSemanticsRole.button
        ..enabled = true
        ..action(GActions.activate);
      button.onAction.add((event) {
        if (event.action != GActions.activate) return;
        activations++;
        event.handle();
      });

      await tester.pumpWidget(_host(root));
      await tester.pump();
      expect(focused.requestFocus(), isTrue);

      final launch = find.semantics.byLabel('Launch');
      expect(launch, findsOne);
      final before = launch.evaluate().single;
      expect(before.value, 'Ready');
      expect(before.hint, 'Starts the demo');
      expect(before.flagsCollection.isButton, isTrue);
      expect(before.flagsCollection.isEnabled != ui.Tristate.none, isTrue);
      expect(before.flagsCollection.isEnabled == ui.Tristate.isTrue, isTrue);
      expect(
        before.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      expect(before.rect, const ui.Rect.fromLTWH(0, 0, 20, 20));
      expect(before.transform!.entry(0, 3), closeTo(40, 1e-9));
      expect(before.transform!.entry(1, 3), closeTo(30, 1e-9));

      tester.semantics.tap(launch);
      await tester.pump();
      expect(activations, 1);
      expect(focused.hasFocus, isTrue);
      expect(button.hasFocus, isFalse);

      final semanticId = before.id;
      button.semantics
        ..label = 'Launch updated'
        ..value = 'Running';
      await tester.pump();
      expect(find.semantics.byLabel('Launch'), findsNothing);
      final updated = find.semantics.byLabel('Launch updated');
      expect(updated, findsOne);
      expect(updated.evaluate().single.id, semanticId);
      expect(updated.evaluate().single.value, 'Running');

      button.visible = false;
      await tester.pump();
      expect(updated.evaluate().single.flagsCollection.isHidden, isTrue);

      button.visible = true;
      button.active = false;
      await tester.pump();
      final disabled = updated.evaluate().single;
      expect(disabled.flagsCollection.isEnabled != ui.Tristate.none, isTrue);
      expect(disabled.flagsCollection.isEnabled == ui.Tristate.isTrue, isFalse);
      expect(
        disabled.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      handle.dispose();
    },
  );

  testWidgets('slider mirrors Flutter focusability and adjust actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final root = GRoot();
    final slider = root.addChild(_SemanticBox('slider'))..focusable = true;
    var value = 50;

    void sync() {
      slider.semantics
        ..label = 'Volume'
        ..role = GSemanticsRole.slider
        ..enabled = true
        ..value = '$value percent'
        ..increasedValue = '${(value + 10).clamp(0, 100)} percent'
        ..decreasedValue = '${(value - 10).clamp(0, 100)} percent'
        ..action(GSemanticsActions.increment)
        ..action(GSemanticsActions.decrement);
    }

    slider.onAction.add((event) {
      if (!event.isPressed) return;
      if (event.action == GSemanticsActions.increment) {
        value = (value + 10).clamp(0, 100);
        sync();
        event.handle();
      } else if (event.action == GSemanticsActions.decrement) {
        value = (value - 10).clamp(0, 100);
        sync();
        event.handle();
      }
    });
    sync();

    await tester.pumpWidget(_host(root));
    await tester.pump();

    final volume = find.semantics.byLabel('Volume');
    expect(volume, findsOne);
    var node = volume.evaluate().single;
    expect(node.flagsCollection.isSlider, isTrue);
    expect(node.flagsCollection.isFocused != ui.Tristate.none, isTrue);
    expect(node.flagsCollection.isFocused == ui.Tristate.isTrue, isFalse);
    expect(node.value, '50 percent');
    expect(node.increasedValue, '60 percent');
    expect(node.decreasedValue, '40 percent');
    expect(
      node.getSemanticsData().hasAction(ui.SemanticsAction.increase),
      isTrue,
    );
    expect(
      node.getSemanticsData().hasAction(ui.SemanticsAction.decrease),
      isTrue,
    );
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.focus), isTrue);

    expect(slider.requestFocus(), isTrue);
    await tester.pump();
    node = volume.evaluate().single;
    expect(node.flagsCollection.isFocused == ui.Tristate.isTrue, isTrue);

    tester.semantics.increase(volume);
    await tester.pump();
    node = volume.evaluate().single;
    expect(value, 60);
    expect(node.value, '60 percent');
    expect(node.increasedValue, '70 percent');
    expect(node.decreasedValue, '50 percent');
    expect(node.flagsCollection.isFocused == ui.Tristate.isTrue, isTrue);

    tester.semantics.decrease(volume);
    await tester.pump();
    node = volume.evaluate().single;
    expect(value, 50);
    expect(node.value, '50 percent');

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });

  testWidgets('merge and exclude policies follow retained scene ancestry', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final root = GRoot();
    final group = root.addChild(GNode(name: 'group'));
    group.semantics
      ..label = 'Group'
      ..mergeDescendants = true;
    final child = group.addChild(_SemanticBox('child'));
    child.semantics.label = 'Child';

    await tester.pumpWidget(_host(root));
    await tester.pump();

    final childFinder = find.semantics.byLabel('Child');
    expect(childFinder, findsOne);
    expect(childFinder.evaluate().single.isMergedIntoParent, isTrue);

    group.semantics.excludeDescendants = true;
    await tester.pump();
    expect(find.semantics.byLabel('Group'), findsOne);
    expect(find.semantics.byLabel('Child'), findsNothing);

    group.semantics.excludeDescendants = false;
    await tester.pump();
    expect(find.semantics.byLabel('Child'), findsOne);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });

  testWidgets('portal descendants keep native Flutter semantics without copy', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final root = GRoot();
    final canvasButton = root.addChild(_SemanticBox('canvas'));
    canvasButton.semantics
      ..label = 'Canvas control'
      ..role = GSemanticsRole.button;

    final portal = root.addChild(
      GPortal<void>(
          width: 120,
          height: 48,
          child: Semantics(
            container: true,
            label: 'Native portal control',
            button: true,
            child: const SizedBox(width: 120, height: 48),
          ),
        )
        ..x = 80
        ..y = 70,
    );
    portal.semantics.label = 'Duplicate portal boundary';

    await tester.pumpWidget(_host(root));
    await tester.pump();

    expect(find.semantics.byLabel('Canvas control'), findsOne);
    expect(find.semantics.byLabel('Native portal control'), findsOne);
    expect(find.semantics.byLabel('Duplicate portal boundary'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });
}

Widget _host(GRoot root) {
  return MaterialApp(
    home: SizedBox(
      width: 400,
      height: 400,
      child: GraphXView(root: () => root),
    ),
  );
}

final class _SemanticBox extends GNode {
  _SemanticBox(String name) : super(name: name);

  @override
  void computeSelfBounds(GBounds out) => out.setXYWH(0, 0, 20, 20);
}
