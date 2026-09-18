import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unconstrained text uses natural layout bounds', () {
    final text = GText(
      'GraphX',
      style: const TextStyle(fontSize: 20, color: Colors.white),
    );

    final bounds = text.getLocalBounds();
    expect(text.textWidth, greaterThan(0));
    expect(text.textHeight, greaterThan(0));
    expect(text.layoutWidth, closeTo(text.textWidth, 0.01));
    expect(bounds.width, closeTo(text.layoutWidth, 0.01));
    expect(bounds.height, closeTo(text.layoutHeight, 0.01));
  });

  test('finite maxWidth is the layout box and wraps text', () {
    const style = TextStyle(fontSize: 18, color: Colors.white);
    final natural = GText(
      'retained paragraph layout with several words',
      style: style,
    );
    final wrapped = GText(
      'retained paragraph layout with several words',
      style: style,
      maxWidth: 90,
    );

    expect(wrapped.layoutWidth, 90);
    expect(wrapped.layoutHeight, greaterThan(natural.layoutHeight));
    expect(wrapped.lineCount, greaterThan(1));
  });

  test('changing maxWidth invalidates retained ancestor bounds', () {
    final parent = GNode();
    final text = parent.addChild(
      GText(
        'GraphX retained text layout',
        maxWidth: 220,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
    );

    final before = parent.getLocalBounds();
    text.maxWidth = 80;
    final after = parent.getLocalBounds();

    expect(before.width, 220);
    expect(after.width, 80);
    expect(after.height, greaterThan(before.height));
  });

  test('paint-only style changes preserve plain text geometry', () {
    final text = GText(
      'retained paint style',
      style: const TextStyle(fontSize: 18, color: Colors.white),
    );

    final beforeWidth = text.textWidth;
    final beforeHeight = text.textHeight;
    final beforeLayoutWidth = text.layoutWidth;
    final beforeLayoutHeight = text.layoutHeight;

    text.style = const TextStyle(fontSize: 18, color: Colors.red);

    expect(text.textWidth, closeTo(beforeWidth, 0.001));
    expect(text.textHeight, closeTo(beforeHeight, 0.001));
    expect(text.layoutWidth, closeTo(beforeLayoutWidth, 0.001));
    expect(text.layoutHeight, closeTo(beforeLayoutHeight, 0.001));
  });

  test('metric style changes still update text geometry', () {
    final text = GText(
      'retained metric style',
      style: const TextStyle(fontSize: 12, color: Colors.white),
    );

    final beforeWidth = text.textWidth;
    final beforeHeight = text.textHeight;
    text.style = const TextStyle(fontSize: 24, color: Colors.white);

    expect(text.textWidth, greaterThan(beforeWidth));
    expect(text.textHeight, greaterThan(beforeHeight));
  });

  test('rich text runs use the shared base style', () {
    final text = GText.rich(const [
      GTextRun('GPU '),
      GTextRun(
        '2.8ms',
        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green),
      ),
    ], style: const TextStyle(fontSize: 16, color: Colors.white));

    expect(text.runs, hasLength(2));
    expect(text.textWidth, greaterThan(0));
    expect(text.lineCount, 1);
  });

  test('paint-only base style changes preserve rich text geometry', () {
    final text = GText.rich(const [
      GTextRun('GPU '),
      GTextRun('2.8ms', style: TextStyle(fontWeight: FontWeight.w700)),
    ], style: const TextStyle(fontSize: 16, color: Colors.white));

    final beforeWidth = text.textWidth;
    final beforeHeight = text.textHeight;
    text.style = const TextStyle(fontSize: 16, color: Colors.blue);

    expect(text.textWidth, closeTo(beforeWidth, 0.001));
    expect(text.textHeight, closeTo(beforeHeight, 0.001));
    expect(text.lineCount, 1);
  });

  test('assigning plain text exits rich mode', () {
    final text = GText.rich(const [
      GTextRun('rich'),
      GTextRun(' text'),
    ], style: const TextStyle(fontSize: 16));

    text.text = 'plain';

    expect(text.runs, isNull);
    expect(text.text, 'plain');
    expect(text.textWidth, greaterThan(0));
  });

  test('maxLines and ellipsis report overflow', () {
    final text = GText(
      'one two three four five six seven eight nine ten',
      maxWidth: 70,
      maxLines: 1,
      ellipsis: '…',
      style: const TextStyle(fontSize: 16),
    );

    expect(text.lineCount, 1);
    expect(text.didExceedMaxLines, isTrue);
  });

  test('invalid layout constraints are rejected', () {
    expect(() => GText('x', maxWidth: -1), throwsArgumentError);
    expect(() => GText('x', maxLines: 0), throwsArgumentError);
  });
}
