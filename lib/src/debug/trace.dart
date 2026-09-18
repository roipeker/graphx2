part of 'package:graphx/src/graphx_impl.dart';

const _traceEnabledByDefault = !bool.fromEnvironment('dart.vm.product');

enum GTraceOutput { console, developer, both }

enum GTraceLevel { log, info, warning, error }

enum GTraceStyle { plain, ansi }

final _traceFramePattern = RegExp(
  r'^\s*#\d+\s+(.+?)\s+\((.+?):(\d+)(?::(\d+))?\)\s*$',
);

typedef GTraceSink = void Function(GTraceRecord record);

const _traceUnset = _TraceUnset();

final class GTraceConfig {
  const GTraceConfig({
    this.enabled = _traceEnabledByDefault,
    this.minLevel = GTraceLevel.log,
    this.tag = 'gx',
    this.separator = ' ',
    this.output = GTraceOutput.console,
    this.style = GTraceStyle.plain,
    this.showFilename = true,
    this.showLineNumber = true,
    this.showColumnNumber = false,
    this.showClassName = true,
    this.showMethodName = true,
  });

  final bool enabled;
  final GTraceLevel minLevel;
  final String tag;
  final String separator;
  final GTraceOutput output;
  final GTraceStyle style;
  final bool showFilename;
  final bool showLineNumber;
  final bool showColumnNumber;
  final bool showClassName;
  final bool showMethodName;

  bool get usesAnsi => style == GTraceStyle.ansi;

  bool get showsCaller =>
      showFilename ||
      showLineNumber ||
      showColumnNumber ||
      showClassName ||
      showMethodName;

  GTraceConfig copyWith({
    bool? enabled,
    GTraceLevel? minLevel,
    String? tag,
    String? separator,
    GTraceOutput? output,
    GTraceStyle? style,
    bool? showFilename,
    bool? showLineNumber,
    bool? showColumnNumber,
    bool? showClassName,
    bool? showMethodName,
  }) {
    return GTraceConfig(
      enabled: enabled ?? this.enabled,
      minLevel: minLevel ?? this.minLevel,
      tag: tag ?? this.tag,
      separator: separator ?? this.separator,
      output: output ?? this.output,
      style: style ?? this.style,
      showFilename: showFilename ?? this.showFilename,
      showLineNumber: showLineNumber ?? this.showLineNumber,
      showColumnNumber: showColumnNumber ?? this.showColumnNumber,
      showClassName: showClassName ?? this.showClassName,
      showMethodName: showMethodName ?? this.showMethodName,
    );
  }
}

final class GTraceCaller {
  const GTraceCaller({
    required this.rawFrame,
    this.className,
    this.methodName,
    this.filename,
    this.line,
    this.column,
  });

  final String rawFrame;
  final String? className;
  final String? methodName;
  final String? filename;
  final int? line;
  final int? column;
}

final class GTraceRecord {
  const GTraceRecord({
    required this.sequence,
    required this.elapsed,
    required this.level,
    required this.tag,
    required this.separator,
    this.category,
    this.caller,
    this.arg0 = _traceUnset,
    this.arg1 = _traceUnset,
    this.arg2 = _traceUnset,
    this.arg3 = _traceUnset,
    this.arg4 = _traceUnset,
    this.arg5 = _traceUnset,
    this.arg6 = _traceUnset,
    this.arg7 = _traceUnset,
    this.arg8 = _traceUnset,
    this.arg9 = _traceUnset,
  });

  final int sequence;
  final Duration elapsed;
  final GTraceLevel level;
  final String tag;
  final String separator;
  final String? category;
  final GTraceCaller? caller;

  final Object? arg0;
  final Object? arg1;
  final Object? arg2;
  final Object? arg3;
  final Object? arg4;
  final Object? arg5;
  final Object? arg6;
  final Object? arg7;
  final Object? arg8;
  final Object? arg9;

  int get argumentCount {
    if (!identical(arg9, _traceUnset)) return 10;
    if (!identical(arg8, _traceUnset)) return 9;
    if (!identical(arg7, _traceUnset)) return 8;
    if (!identical(arg6, _traceUnset)) return 7;
    if (!identical(arg5, _traceUnset)) return 6;
    if (!identical(arg4, _traceUnset)) return 5;
    if (!identical(arg3, _traceUnset)) return 4;
    if (!identical(arg2, _traceUnset)) return 3;
    if (!identical(arg1, _traceUnset)) return 2;
    if (!identical(arg0, _traceUnset)) return 1;
    return 0;
  }

  Object? operator [](int index) {
    final count = argumentCount;
    if (index < 0 || index >= count) {
      throw RangeError.index(index, this, 'index', null, count);
    }
    return switch (index) {
      0 => arg0,
      1 => arg1,
      2 => arg2,
      3 => arg3,
      4 => arg4,
      5 => arg5,
      6 => arg6,
      7 => arg7,
      8 => arg8,
      9 => arg9,
      _ => throw StateError('unreachable'),
    };
  }

  Iterable<Object?> get arguments sync* {
    final count = argumentCount;
    for (int i = 0; i < count; i++) {
      yield this[i];
    }
  }

  String get message => _traceFormatMessage(this);

  String get name {
    final category = this.category;
    if (category == null || category.isEmpty) return tag;
    if (tag.isEmpty) return category;
    return '$tag.$category';
  }
}

final class _TraceUnset {
  const _TraceUnset();
}

final class GTrace {
  GTrace._();

  GTraceConfig _config = const GTraceConfig();
  GTraceSink? sink;
  int _sequence = 0;

  GTraceConfig get config => _config;
  bool get enabled => _config.enabled;

  set enabled(bool value) {
    if (value == _config.enabled) return;
    _config = _config.copyWith(enabled: value);
  }

  void configure({
    bool? enabled,
    GTraceLevel? minLevel,
    String? tag,
    String? separator,
    GTraceOutput? output,
    GTraceStyle? style,
    bool? showFilename,
    bool? showLineNumber,
    bool? showColumnNumber,
    bool? showClassName,
    bool? showMethodName,
  }) {
    _config = _config.copyWith(
      enabled: enabled,
      minLevel: minLevel,
      tag: tag,
      separator: separator,
      output: output,
      style: style,
      showFilename: showFilename,
      showLineNumber: showLineNumber,
      showColumnNumber: showColumnNumber,
      showClassName: showClassName,
      showMethodName: showMethodName,
    );
  }

  void reset() {
    _config = const GTraceConfig();
    sink = null;
    _sequence = 0;
  }

  GTraceCategory category(String name) => GTraceCategory._(this, name.trim());

  void call([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _write(
    GTraceLevel.log,
    null,
    false,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  void info([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _write(
    GTraceLevel.info,
    null,
    false,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  void warn([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _write(
    GTraceLevel.warning,
    null,
    false,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  void error([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _write(
    GTraceLevel.error,
    null,
    false,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  void caller([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _write(
    GTraceLevel.log,
    null,
    true,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  bool _allows(GTraceLevel level) {
    final config = _config;
    return config.enabled && level.index >= config.minLevel.index;
  }

  void _write(
    GTraceLevel level,
    String? category,
    bool captureCaller,
    Object? a0,
    Object? a1,
    Object? a2,
    Object? a3,
    Object? a4,
    Object? a5,
    Object? a6,
    Object? a7,
    Object? a8,
    Object? a9,
  ) {
    if (!_allows(level)) return;
    final config = _config;
    if (!_traceHasArgument(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)) return;

    final normalizedCategory = category == null || category.isEmpty
        ? null
        : category;
    final record = GTraceRecord(
      sequence: ++_sequence,
      elapsed: runtimeElapsed,
      level: level,
      tag: config.tag,
      separator: config.separator,
      category: normalizedCategory,
      caller: captureCaller ? _traceFindCaller() : null,
      arg0: a0,
      arg1: a1,
      arg2: a2,
      arg3: a3,
      arg4: a4,
      arg5: a5,
      arg6: a6,
      arg7: a7,
      arg8: a8,
      arg9: a9,
    );

    final outputSink = sink;
    if (outputSink != null) {
      outputSink(record);
      return;
    }

    switch (config.output) {
      case GTraceOutput.console:
        _traceWriteConsole(record, config);
      case GTraceOutput.developer:
        _traceWriteDeveloper(record, config);
      case GTraceOutput.both:
        _traceWriteConsole(record, config);
        _traceWriteDeveloper(record, config);
    }
  }
}

final class GTraceCategory {
  const GTraceCategory._(this._trace, this.name);

  final GTrace _trace;
  final String name;

  bool get enabled => _trace.enabled;

  void call([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _trace._write(
    GTraceLevel.log,
    name,
    false,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  void info([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _trace._write(
    GTraceLevel.info,
    name,
    false,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  void warn([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _trace._write(
    GTraceLevel.warning,
    name,
    false,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  void error([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _trace._write(
    GTraceLevel.error,
    name,
    false,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );

  void caller([
    Object? a0 = _traceUnset,
    Object? a1 = _traceUnset,
    Object? a2 = _traceUnset,
    Object? a3 = _traceUnset,
    Object? a4 = _traceUnset,
    Object? a5 = _traceUnset,
    Object? a6 = _traceUnset,
    Object? a7 = _traceUnset,
    Object? a8 = _traceUnset,
    Object? a9 = _traceUnset,
  ]) => _trace._write(
    GTraceLevel.log,
    name,
    true,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
  );
}

final trace = GTrace._();

bool _traceHasArgument(
  Object? a0,
  Object? a1,
  Object? a2,
  Object? a3,
  Object? a4,
  Object? a5,
  Object? a6,
  Object? a7,
  Object? a8,
  Object? a9,
) {
  return !identical(a0, _traceUnset) ||
      !identical(a1, _traceUnset) ||
      !identical(a2, _traceUnset) ||
      !identical(a3, _traceUnset) ||
      !identical(a4, _traceUnset) ||
      !identical(a5, _traceUnset) ||
      !identical(a6, _traceUnset) ||
      !identical(a7, _traceUnset) ||
      !identical(a8, _traceUnset) ||
      !identical(a9, _traceUnset);
}

String _traceFormatMessage(GTraceRecord record) {
  final output = StringBuffer();
  final count = record.argumentCount;
  for (int i = 0; i < count; i++) {
    if (i > 0) output.write(record.separator);
    output.write(record[i]);
  }
  return output.toString();
}

void _traceWriteConsole(GTraceRecord record, GTraceConfig config) {
  final output = _traceFormatRecord(record, config, ansi: config.usesAnsi);
  if (config.usesAnsi) {
    // ignore: avoid_print
    print(output);
  } else {
    debugPrint(output);
  }
}

void _traceWriteDeveloper(GTraceRecord record, GTraceConfig config) {
  final caller = _traceFormatCallerPlain(record.caller, config);
  final message = record.message;
  developer.log(
    caller == null ? message : '$caller · $message',
    name: record.name,
    level: switch (record.level) {
      GTraceLevel.log => 500,
      GTraceLevel.info => 800,
      GTraceLevel.warning => 900,
      GTraceLevel.error => 1000,
    },
    sequenceNumber: record.sequence,
  );
}

String _traceFormatRecord(
  GTraceRecord record,
  GTraceConfig config, {
  required bool ansi,
}) {
  final output = StringBuffer();
  _traceWritePrefix(output, record, ansi: ansi);
  _traceWriteLevel(output, record.level, ansi: ansi);

  final caller = record.caller;
  if (caller != null && config.showsCaller) {
    final location = _traceFormatLocation(caller, config);
    final symbol = _traceFormatSymbol(caller, config);

    if (location != null) {
      if (output.length > 0) output.write(' ');
      if (ansi) {
        output
          ..write(_Ansi.dim)
          ..write(location)
          ..write(_Ansi.reset);
      } else {
        output.write(location);
      }
    }

    if (symbol != null) {
      if (output.length > 0) output.write(' · ');
      if (ansi) {
        output
          ..write(_Ansi.brightBlue)
          ..write(symbol)
          ..write(_Ansi.reset);
      } else {
        output.write(symbol);
      }
    }
  }

  if (output.length > 0) output.write(record.caller == null ? '  ' : ' · ');
  output.write(record.message);
  if (ansi) output.write(_Ansi.reset);
  return output.toString();
}

void _traceWritePrefix(
  StringBuffer output,
  GTraceRecord record, {
  required bool ansi,
}) {
  final tag = record.tag;
  final category = record.category;
  if (tag.isEmpty && (category == null || category.isEmpty)) return;

  output.write('[');
  if (tag.isNotEmpty) {
    if (ansi) output.write(_Ansi.brightCyan);
    output.write(tag);
    if (ansi) output.write(_Ansi.reset);
  }
  if (category != null && category.isNotEmpty) {
    if (tag.isNotEmpty) output.write('/');
    if (ansi) output.write(_traceCategoryColor(category));
    output.write(category);
    if (ansi) output.write(_Ansi.reset);
  }
  output.write(']');
}

void _traceWriteLevel(
  StringBuffer output,
  GTraceLevel level, {
  required bool ansi,
}) {
  if (level == GTraceLevel.log) return;
  if (output.length > 0) output.write(' ');

  final label = switch (level) {
    GTraceLevel.log => '',
    GTraceLevel.info => 'INFO ',
    GTraceLevel.warning => 'WARN ',
    GTraceLevel.error => 'ERROR',
  };

  if (ansi) {
    output.write(switch (level) {
      GTraceLevel.log => _Ansi.reset,
      GTraceLevel.info => _Ansi.brightBlue,
      GTraceLevel.warning => _Ansi.brightYellow,
      GTraceLevel.error => _Ansi.brightRed,
    });
  }
  output.write(label);
  if (ansi) output.write(_Ansi.reset);
}

String? _traceFormatCallerPlain(GTraceCaller? caller, GTraceConfig config) {
  if (caller == null || !config.showsCaller) return null;
  final location = _traceFormatLocation(caller, config);
  final symbol = _traceFormatSymbol(caller, config);
  if (location == null) return symbol;
  if (symbol == null) return location;
  return '$location · $symbol';
}

String? _traceFormatLocation(GTraceCaller caller, GTraceConfig config) {
  final output = StringBuffer();
  if (config.showFilename && caller.filename?.isNotEmpty == true) {
    output.write(caller.filename);
  }
  if (config.showLineNumber && caller.line != null) {
    output.write(output.length > 0 ? ':' : 'line ');
    output.write(caller.line);
  }
  if (config.showColumnNumber && caller.column != null) {
    output.write(output.length > 0 ? ':' : 'column ');
    output.write(caller.column);
  }
  return output.length == 0 ? null : output.toString();
}

String? _traceFormatSymbol(GTraceCaller caller, GTraceConfig config) {
  final output = StringBuffer();
  final className = caller.className;
  final methodName = caller.methodName;
  if (config.showClassName && className != null && className.isNotEmpty) {
    output.write(className);
  }
  if (config.showMethodName && methodName != null && methodName.isNotEmpty) {
    if (output.length > 0) output.write('.');
    output.write(methodName);
  }
  return output.length == 0 ? null : output.toString();
}

abstract final class _Ansi {
  static const reset = '\x1B[0m';
  static const dim = '\x1B[2m';
  static const brightRed = '\x1B[91m';
  static const brightYellow = '\x1B[93m';
  static const brightBlue = '\x1B[94m';
  static const brightMagenta = '\x1B[95m';
  static const brightCyan = '\x1B[96m';
  static const brightGreen = '\x1B[92m';
  static const yellow = '\x1B[33m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
}

String _traceCategoryColor(String category) {
  int hash = 0;
  for (int i = 0; i < category.length; i++) {
    hash = ((hash * 31) + category.codeUnitAt(i)) & 0x7fffffff;
  }
  return switch (hash % 6) {
    0 => _Ansi.brightMagenta,
    1 => _Ansi.brightGreen,
    2 => _Ansi.brightYellow,
    3 => _Ansi.magenta,
    4 => _Ansi.yellow,
    _ => _Ansi.cyan,
  };
}

GTraceCaller? _traceFindCaller() {
  final frames = StackTrace.current.toString().split('\n');
  GTraceCaller? fallback;
  for (final rawFrame in frames) {
    final frame = rawFrame.trim();
    if (frame.isEmpty || _traceIsInternalFrame(frame)) continue;
    final caller = _traceParseCaller(frame);
    if (caller == null) continue;
    fallback ??= caller;
    if (caller.filename != null && caller.line != null) return caller;
  }
  return fallback;
}

GTraceCaller? _traceParseCaller(String frame) {
  final match = _traceFramePattern.firstMatch(frame);
  if (match == null) return GTraceCaller(rawFrame: frame);
  final symbol = _traceCleanSymbol(match.group(1)!.trim());
  final uri = match.group(2)!;
  final parts = _traceSplitSymbol(symbol);
  return GTraceCaller(
    rawFrame: frame,
    className: parts.className,
    methodName: parts.methodName,
    filename: _traceFilename(uri),
    line: int.tryParse(match.group(3)!),
    column: switch (match.group(4)) {
      final String value => int.tryParse(value),
      null => null,
    },
  );
}

String _traceCleanSymbol(String symbol) {
  const suffixes = <String>['.<anonymous closure>', '.<fn>'];
  var result = symbol;
  for (final suffix in suffixes) {
    while (result.endsWith(suffix)) {
      result = result.substring(0, result.length - suffix.length);
    }
  }
  return result;
}

({String? className, String? methodName}) _traceSplitSymbol(String symbol) {
  final dot = symbol.lastIndexOf('.');
  if (dot <= 0 || dot == symbol.length - 1) {
    return (className: null, methodName: symbol.isEmpty ? null : symbol);
  }
  return (
    className: symbol.substring(0, dot),
    methodName: symbol.substring(dot + 1),
  );
}

bool _traceIsInternalFrame(String frame) {
  return frame.contains('_traceFindCaller') ||
      frame.contains('_traceParseCaller') ||
      frame.contains('_traceWrite') ||
      frame.contains('GTrace.') ||
      frame.contains('GTraceCategory.');
}

String _traceFilename(String uri) {
  final slash = uri.lastIndexOf('/');
  return slash < 0 ? uri : uri.substring(slash + 1);
}

final class GDebugString {
  GDebugString(this.type);

  final String type;
  final StringBuffer _buffer = StringBuffer();
  bool _hasValue = false;

  void value(Object? value) {
    if (value == null) return;
    _separator();
    _buffer.write(value);
  }

  void field(String name, Object? value) {
    if (value == null) return;
    _separator();
    _buffer
      ..write(name)
      ..write('=')
      ..write(value);
  }

  void _separator() {
    if (_hasValue) _buffer.write(', ');
    _hasValue = true;
  }

  @override
  String toString() => '$type($_buffer)';
}
