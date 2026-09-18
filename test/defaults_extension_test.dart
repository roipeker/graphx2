import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GDefaults subclasses remain normal core defaults scopes', () {
    final theme = _ThemeScope(
      textStyle: const GTextStyle(fontSize: 22, color: Colors.teal),
      iconStyle: const GIconStyle(size: 30, color: Colors.amber),
    );
    final text = theme.addChild(GText('GraphX'));
    final icon = theme.addChild(GIcon(Icons.add));

    expect(text.color, Colors.teal);
    expect(text.textHeight, greaterThan(20));
    expect(icon.size, 30);
    expect(icon.color, Colors.amber);
  });

  test('nested defaults subclasses preserve sparse core cascading', () {
    final outer = _ThemeScope(
      textStyle: const GTextStyle(fontSize: 28, color: Colors.red),
    );
    final inner = outer.addChild(
      _ThemeScope(textStyle: const GTextStyle(color: Colors.blue)),
    );
    final text = inner.addChild(GText('GraphX'));

    expect(text.color, Colors.blue);
    final height = text.textHeight;

    outer.textStyle = const GTextStyle(fontSize: 36, color: Colors.green);

    expect(text.color, Colors.blue);
    expect(text.textHeight, greaterThan(height));
  });

  test(
    'cached detached visuals resolve defaults when entering and leaving scope',
    () {
      final text = GText('GraphX');
      final icon = GIcon(Icons.add);

      // Materialize fallback resolution before either visual has a scoped parent.
      expect(text.color, GText.defaultStyle.color);
      expect(icon.size, GIcon.defaultStyle.size);

      final theme = _ThemeScope(
        textStyle: const GTextStyle(color: Colors.purple, fontSize: 24),
        iconStyle: const GIconStyle(size: 37, color: Colors.orange),
      );
      theme
        ..addChild(text)
        ..addChild(icon);

      expect(text.color, Colors.purple);
      expect(icon.size, 37);
      expect(icon.color, Colors.orange);

      theme
        ..removeChild(text)
        ..removeChild(icon);

      expect(text.color, GText.defaultStyle.color);
      expect(icon.size, GIcon.defaultStyle.size);
      expect(icon.color, GIcon.defaultStyle.color);
    },
  );

  test('arbitrary subtree reparent invalidates package defaults consumers', () {
    final red = _ThemeScope(uiToken: 1);
    final blue = _ThemeScope(uiToken: 2);
    final branch = GNode(name: 'branch');
    final consumer = branch.addChild(_DefaultsConsumer());

    red.addChild(branch);
    expect(consumer.changeCount, 1);
    expect(consumer.resolveToken(), 1);

    consumer.reset();
    blue.addChild(branch);
    expect(consumer.changeCount, 1);
    expect(consumer.resolveToken(), 2);

    consumer.reset();
    blue.removeChild(branch);
    expect(consumer.changeCount, 1);
    expect(consumer.resolveToken(), isNull);
  });

  test(
    'defaults subclasses can invalidate only package-specific consumers',
    () {
      final theme = _ThemeScope(uiToken: 1);
      final consumer = theme.addChild(_DefaultsConsumer());

      consumer.reset();
      theme.uiToken = 2;

      expect(consumer.changeCount, 1);
      expect(consumer.resolveToken(), 2);
    },
  );
}

final class _ThemeScope extends GDefaults {
  _ThemeScope({super.textStyle, super.iconStyle, int? uiToken})
    : _uiToken = uiToken;

  int? _uiToken;

  int? get uiToken => _uiToken;
  set uiToken(int? value) {
    if (_uiToken == value) return;
    _uiToken = value;
    invalidateDescendantDefaults();
  }
}

final class _DefaultsConsumer extends GNode {
  int changeCount = 0;

  void reset() => changeCount = 0;

  int? resolveToken() {
    for (var node = parent; node != null; node = node.parent) {
      if (node is _ThemeScope) return node.uiToken;
    }
    return null;
  }

  @override
  void inheritedDefaultsChanged() => changeCount++;
}
