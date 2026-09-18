// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  testWidgets('portal transform updates do not rebuild content', (
    tester,
  ) async {
    late GPortal<int> portal;
    var builds = 0;
    const childKey = ValueKey('portal-child');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GraphXView.scene((root) {
            final group = root.addChild(
              GNode()
                ..x = 30
                ..y = 20,
            );
            portal = group.addChild(
              GPortal<int>.builder(
                  value: 1,
                  width: 120,
                  height: 40,
                  builder: (context, value) {
                    builds++;
                    return Container(
                      key: childKey,
                      color: Colors.red,
                      child: Text('value $value'),
                    );
                  },
                )
                ..x = 20
                ..y = 10,
            );
          }),
        ),
      ),
    );

    expect(builds, 1);
    expect(tester.getTopLeft(find.byKey(childKey)), const Offset(50, 30));

    portal
      ..x = 80
      ..y = 50
      ..scaleX = 1.25
      ..rotation = .1
      ..alpha = .75;
    await tester.pump();

    expect(builds, 1);
    expect(tester.getTopLeft(find.byKey(childKey)).dx, greaterThan(100));

    portal.value = 2;
    await tester.pump();
    expect(find.text('value 2'), findsOneWidget);
    expect(builds, 2);
  });

  testWidgets('portal uses normal Flutter layout for natural size', (
    tester,
  ) async {
    late GPortal<Object?> portal;
    const childKey = ValueKey('natural-portal-child');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GraphXView.scene((root) {
            portal = root.addChild(
              GPortal(
                  child: const SizedBox(key: childKey, width: 137, height: 43),
                )
                ..x = 20
                ..y = 30,
            );
          }),
        ),
      ),
    );

    expect(portal.width, isNull);
    expect(portal.height, isNull);
    expect(portal.layoutSize.width, 137);
    expect(portal.layoutSize.height, 43);
    expect(tester.getSize(find.byKey(childKey)), const Size(137, 43));
  });

  testWidgets('portal can constrain width while Flutter chooses height', (
    tester,
  ) async {
    late GPortal<Object?> portal;
    const childKey = ValueKey('width-constrained-child');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GraphXView.scene((root) {
            portal = root.addChild(
              GPortal(
                width: 180,
                child: const SizedBox(key: childKey, height: 57),
              ),
            );
          }),
        ),
      ),
    );

    expect(portal.width, 180);
    expect(portal.height, isNull);
    expect(portal.layoutSize.width, 180);
    expect(portal.layoutSize.height, 57);
  });

  testWidgets('layoutSize signal follows content layout changes', (
    tester,
  ) async {
    late GPortal<int> portal;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GraphXView.scene((root) {
            portal = root.addChild(
              GPortal<int>.builder(
                value: 1,
                width: 160,
                builder: (context, value) => SizedBox(height: value == 1 ? 40 : 76),
              ),
            );
          }),
        ),
      ),
    );

    expect(portal.layoutSize.width, 160);
    expect(portal.layoutSize.height, 40);

    var changes = 0;
    portal.onLayoutSizeChanged.add(() => changes++);

    portal.value = 2;
    await tester.pump();

    expect(portal.layoutSize.width, 160);
    expect(portal.layoutSize.height, 76);
    expect(changes, 1);
  });

  for (final repaintBoundary in [true, false]) {
    testWidgets(
      'behind portal transforms with repaintBoundary=$repaintBoundary',
      (tester) async {
        late GPortal<Object?> portal;
        const childKey = ValueKey('behind-portal-child');

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 400,
              height: 300,
              child: GraphXView.scene(
                (root) {
                  portal = root.addChild(
                    GPortal(
                        width: 100,
                        height: 60,
                        repaintBoundary: repaintBoundary,
                        placement: GPortalPlacement.behind,
                        child: Container(key: childKey, color: Colors.blue),
                      )
                      ..x = 40
                      ..y = 50,
                  );
                },
                config: GraphXConfig.sceneDefaults.copyWith(
                  hitTestBehavior: GHitTestBehavior.content,
                ),
              ),
            ),
          ),
        );

        expect(tester.getTopLeft(find.byKey(childKey)), const Offset(40, 50));

        portal
          ..x = 140
          ..y = 120
          ..rotation = .08
          ..alpha = .5;
        await tester.pump();

        expect(tester.getTopLeft(find.byKey(childKey)).dx, greaterThan(130));
        expect(tester.getTopLeft(find.byKey(childKey)).dy, greaterThan(110));
      },
    );
  }

  testWidgets('pointerEnabled controls Flutter child hit testing', (
    tester,
  ) async {
    late GPortal<Object?> portal;
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GraphXView.scene(
            (root) {
              portal = root.addChild(
                GPortal(
                    width: 120,
                    height: 60,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: const SizedBox.expand(),
                    ),
                  )
                  ..x = 20
                  ..y = 20,
              );
            },
            config: GraphXConfig.sceneDefaults.copyWith(
              hitTestBehavior: GHitTestBehavior.content,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(taps, 1);

    portal.pointerEnabled = false;
    await tester.pump();
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(taps, 1);
  });
}
