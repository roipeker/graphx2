// Copyright (c) 2026 GraphX by roipeker.

// ignore_for_file: avoid_print

import 'dart:io';

Future<void> main(List<String> arguments) async {
  final options = _RunnerOptions.parse(arguments);
  final root = Directory.current.absolute;
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('Run this command from the GraphX package root.');
    exitCode = 64;
    return;
  }

  final host = Directory('${root.path}/.dart_tool/graphx_benchmark_host');
  final hostPubspec = File('${host.path}/pubspec.yaml');
  if (!hostPubspec.existsSync()) {
    host.createSync(recursive: true);
    await _runChecked(
      'flutter',
      <String>[
        'create',
        '--platforms=macos,web',
        '--project-name',
        'graphx_benchmark_host',
        '.',
      ],
      workingDirectory: host.path,
    );
    await _runChecked(
      'flutter',
      <String>['pub', 'add', 'graphx', '--path', root.path],
      workingDirectory: host.path,
    );
  }

  final benchmarkLink = Link('${host.path}/lib/benchmark');
  if (benchmarkLink.existsSync()) {
    benchmarkLink.deleteSync();
  }
  benchmarkLink.createSync('${root.path}/benchmark');

  final target = switch (options.target) {
    _BenchmarkTarget.baseline => 'performance_baseline.dart',
    _BenchmarkTarget.lab => 'performance_lab.dart',
  };
  final command = <String>[
    'run',
    '-d',
    options.device,
    '--profile',
  ];
  if (options.smoke) {
    if (options.target != _BenchmarkTarget.lab) {
      stderr.writeln('--smoke is only valid with --lab.');
      exitCode = 64;
      return;
    }
    command.add('--dart-define=GRAPHX_PERFORMANCE_LAB_SMOKE=true');
  }
  command.addAll(<String>['-t', 'lib/benchmark/$target']);
  print('benchmark host: ${host.path}');
  print('flutter ${command.join(' ')}');
  final process = await Process.start(
    'flutter',
    command,
    workingDirectory: host.path,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}

Future<void> _runChecked(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    throw ProcessException(executable, arguments, 'command failed', code);
  }
}

enum _BenchmarkTarget { baseline, lab }

final class _RunnerOptions {
  const _RunnerOptions({
    required this.device,
    required this.target,
    required this.smoke,
  });

  factory _RunnerOptions.parse(List<String> arguments) {
    var device = 'macos';
    var target = _BenchmarkTarget.baseline;
    var smoke = false;
    for (final argument in arguments) {
      if (argument.startsWith('--device=')) {
        device = argument.substring('--device='.length);
        continue;
      }
      if (argument == '--lab') {
        target = _BenchmarkTarget.lab;
        continue;
      }
      if (argument == '--baseline') {
        target = _BenchmarkTarget.baseline;
        continue;
      }
      if (argument == '--smoke') {
        smoke = true;
        continue;
      }
      if (argument == '--help' || argument == '-h') {
        print(
          'dart run benchmark/run.dart [--baseline|--lab] '
          '[--device=macos|chrome] [--smoke]',
        );
        exit(0);
      }
      stderr.writeln('Unknown argument: $argument');
      exit(64);
    }
    return _RunnerOptions(device: device, target: target, smoke: smoke);
  }

  final String device;
  final _BenchmarkTarget target;
  final bool smoke;
}
