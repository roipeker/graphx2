import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx_debug.dart';

void main() {
  final records = <GTraceRecord>[];

  setUp(() {
    trace.reset();
    records.clear();
    trace.sink = records.add;
  });

  tearDown(trace.reset);

  test('trace keeps supplied values structured', () {
    final marker = Object();

    trace('node', null, marker, 42);

    final record = records.single;
    expect(record.level, GTraceLevel.log);
    expect(record.argumentCount, 4);
    expect(record[0], 'node');
    expect(record[1], isNull);
    expect(identical(record[2], marker), isTrue);
    expect(record[3], 42);
    expect(record.arguments.toList(), ['node', null, marker, 42]);
  });

  test('trace formats only when message is requested', () {
    trace.configure(separator: ' | ');
    trace('a', null, 3);
    expect(records.single.message, 'a | null | 3');
  });

  test('trace with no arguments does nothing', () {
    trace();
    expect(records, isEmpty);
  });

  test('severity methods emit structured levels', () {
    trace.info('info');
    trace.warn('warn');
    trace.error('error');

    expect(records.map((record) => record.level), [
      GTraceLevel.info,
      GTraceLevel.warning,
      GTraceLevel.error,
    ]);
  });

  test('category returns reusable channel', () {
    final render = trace.category(' render ');

    render('painted', 12);
    render.warn('slow', 20);
    render.error('failed');

    expect(render.name, 'render');
    expect(records.map((record) => record.category), [
      'render',
      'render',
      'render',
    ]);
    expect(records.map((record) => record.level), [
      GTraceLevel.log,
      GTraceLevel.warning,
      GTraceLevel.error,
    ]);
    expect(records.first.name, 'gx.render');
  });

  test('empty category behaves like uncategorized trace', () {
    trace.category('')('plain');

    expect(records.single.category, isNull);
    expect(records.single.name, 'gx');
  });

  test('category caller capture is opt-in', () {
    final render = trace.category('render');

    render('plain');
    render.caller('with caller');

    expect(records[0].caller, isNull);
    expect(records[1].caller, isNotNull);
  });

  test('minLevel filters before records are emitted', () {
    trace.configure(minLevel: GTraceLevel.warning);

    trace('log');
    trace.info('info');
    trace.warn('warn');
    trace.error('error');

    expect(records, hasLength(2));
    expect(records[0].level, GTraceLevel.warning);
    expect(records[1].level, GTraceLevel.error);
  });

  test('minLevel applies to reusable categories', () {
    final input = trace.category('input');
    trace.configure(minLevel: GTraceLevel.error);

    input('log');
    input.warn('warn');
    input.error('error');

    expect(records, hasLength(1));
    expect(records.single.category, 'input');
    expect(records.single.level, GTraceLevel.error);
  });

  test('disabled trace does not emit records', () {
    final render = trace.category('render');
    trace.enabled = false;

    trace('ignored');
    trace.info('ignored');
    render('ignored');
    render.error('ignored');
    trace.caller('ignored');

    expect(records, isEmpty);
  });

  test('configuration remains immutable from consumers', () {
    final before = trace.config;

    trace.configure(
      minLevel: GTraceLevel.info,
      tag: 'graphx',
      separator: ':',
      style: GTraceStyle.ansi,
      output: GTraceOutput.both,
    );

    expect(before.tag, 'gx');
    expect(before.minLevel, GTraceLevel.log);
    expect(trace.config.tag, 'graphx');
    expect(trace.config.minLevel, GTraceLevel.info);
    expect(trace.config.separator, ':');
    expect(trace.config.style, GTraceStyle.ansi);
    expect(trace.config.output, GTraceOutput.both);
  });

  test('sink can be replaced and cleared', () {
    final other = <GTraceRecord>[];

    trace.sink = other.add;
    trace('other');

    expect(records, isEmpty);
    expect(other, hasLength(1));

    trace.sink = null;
    expect(trace.sink, isNull);
  });

  test('sequence increments only for emitted traces', () {
    trace.configure(minLevel: GTraceLevel.info);
    trace('filtered');
    trace();
    trace.info('one');
    trace.warn('two');

    expect(records[0].sequence, 1);
    expect(records[1].sequence, 2);
  });

  test('reset clears sink sequence and configuration', () {
    trace.configure(tag: 'custom', minLevel: GTraceLevel.error, enabled: false);
    trace.reset();

    expect(trace.sink, isNull);
    expect(trace.config.tag, 'gx');
    expect(trace.config.minLevel, GTraceLevel.log);

    trace.sink = records.add;
    trace('first');

    expect(records.single.sequence, 1);
  });
}
