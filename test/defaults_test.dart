import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('text defaults cascade property by property', () {
    final outer = GDefaults(
      textStyle: const GTextStyle(fontSize: 18, color: Colors.red),
    );
    final inner = outer.addChild(
      GDefaults(textStyle: const GTextStyle(color: Colors.blue)),
    );
    final text = inner.addChild(
      GText('GraphX', style: const GTextStyle(fontWeight: FontWeight.w700)),
    );

    expect(text.color, Colors.blue);
    final before = text.textHeight;

    outer.textStyle = const GTextStyle(fontSize: 30, color: Colors.green);

    expect(text.color, Colors.blue);
    expect(text.textHeight, greaterThan(before));
  });

  test('local text style wins over scoped defaults', () {
    final defaults = GDefaults(
      textStyle: const GTextStyle(fontSize: 24, color: Colors.red),
    );
    final inherited = defaults.addChild(GText('A'));
    final local = defaults.addChild(
      GText('A', style: const GTextStyle(fontSize: 10, color: Colors.green)),
    );

    expect(inherited.color, Colors.red);
    expect(local.color, Colors.green);
    expect(inherited.textHeight, greaterThan(local.textHeight));
  });

  test('text scaler is explicit and inherited through defaults', () {
    final defaults = GDefaults(
      textStyle: const GTextStyle(fontSize: 12),
      textScaler: const TextScaler.linear(2),
    );
    final scaled = defaults.addChild(GText('GraphX'));
    final fixed = GText('GraphX', style: const GTextStyle(fontSize: 12));

    expect(scaled.textHeight, greaterThan(fixed.textHeight));

    final before = scaled.textHeight;
    defaults.textScaler = TextScaler.noScaling;
    expect(scaled.textHeight, lessThan(before));
  });

  test('nearest text scaler scope wins', () {
    final outer = GDefaults(textScaler: const TextScaler.linear(2));
    final inner = outer.addChild(GDefaults(textScaler: TextScaler.noScaling));
    final text = inner.addChild(
      GText('GraphX', style: const GTextStyle(fontSize: 12)),
    );
    final fixed = GText('GraphX', style: const GTextStyle(fontSize: 12));

    expect(text.textHeight, closeTo(fixed.textHeight, .01));
  });

  test('icon defaults cascade and direct properties stay local', () {
    final outer = GDefaults(
      iconStyle: const GIconStyle(size: 32, color: Colors.red),
    );
    final inner = outer.addChild(
      GDefaults(iconStyle: const GIconStyle(color: Colors.blue)),
    );
    final icon = inner.addChild(GIcon(Icons.add));

    expect(icon.size, 32);
    expect(icon.color, Colors.blue);

    icon.size = 20;
    icon.color = Colors.green;
    outer.iconStyle = const GIconStyle(size: 48, color: Colors.orange);

    expect(icon.size, 20);
    expect(icon.color, Colors.green);

    icon.size = null;
    icon.color = null;
    expect(icon.size, 48);
    expect(icon.color, Colors.blue);
  });

  test('engine fallbacks remain deterministic without a scope', () {
    final text = GText('GraphX');
    final icon = GIcon(Icons.add);

    expect(text.color, GText.defaultStyle.color);
    expect(icon.size, GIcon.defaultStyle.size);
    expect(icon.color, GIcon.defaultStyle.color);
  });

  test('mutating defaults invalidates retained descendant bounds', () {
    final defaults = GDefaults(
      textStyle: const GTextStyle(fontSize: 10),
      iconStyle: const GIconStyle(size: 12),
    );
    final text = defaults.addChild(GText('GraphX'));
    final icon = defaults.addChild(GIcon(Icons.add));

    final textBefore = text.getLocalBounds().height;
    expect(icon.getLocalBounds().width, 12);

    defaults.textStyle = const GTextStyle(fontSize: 28);
    defaults.iconStyle = const GIconStyle(size: 40);

    expect(text.getLocalBounds().height, greaterThan(textBefore));
    expect(icon.getLocalBounds().width, 40);
  });

  test('same-stage reparent resolves the new defaults branch', () {
    final root = GRoot();
    final red = root.addChild(
      GDefaults(
        textStyle: const GTextStyle(color: Colors.red),
        iconStyle: const GIconStyle(size: 20, color: Colors.red),
      ),
    );
    final blue = root.addChild(
      GDefaults(
        textStyle: const GTextStyle(color: Colors.blue),
        iconStyle: const GIconStyle(size: 36, color: Colors.blue),
      ),
    );
    final branch = red.addChild(GNode());
    final text = branch.addChild(GText('GraphX'));
    final icon = branch.addChild(GIcon(Icons.add));
    final stage = GStage(root);

    stage.mount();
    stage.setViewport(100, 100);
    expect(text.color, Colors.red);
    expect(icon.size, 20);
    expect(icon.color, Colors.red);

    blue.addChild(branch);
    expect(text.color, Colors.blue);
    expect(icon.size, 36);
    expect(icon.color, Colors.blue);

    stage.dispose();
  });
}
