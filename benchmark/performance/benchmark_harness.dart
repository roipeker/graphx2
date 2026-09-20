// Copyright (c) 2026 GraphX by roipeker.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

const graphXBenchmarkSchema = 'GRAPHX_BENCHMARK_V1';
final int _stopwatchFrequency = Stopwatch().frequency;

final class GraphXBenchmarkEnvironment {
  GraphXBenchmarkEnvironment._({
    required this.mode,
    required this.web,
    required this.platform,
    required this.devicePixelRatio,
    required this.stopwatchFrequency,
  });

  factory GraphXBenchmarkEnvironment.capture() {
    final views = ui.PlatformDispatcher.instance.views;
    final dpr = views.isEmpty ? 1.0 : views.first.devicePixelRatio;
    return GraphXBenchmarkEnvironment._(
      mode: kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      web: kIsWeb,
      platform: defaultTargetPlatform.name,
      devicePixelRatio: dpr,
      stopwatchFrequency: _stopwatchFrequency,
    );
  }

  final String mode;
  final bool web;
  final String platform;
  final double devicePixelRatio;
  final int stopwatchFrequency;

  String get target => web ? 'web' : 'native';

  Map<String, Object> toJson() => <String, Object>{
    'mode': mode,
    'target': target,
    'web': web,
    'platform': platform,
    'device_pixel_ratio': devicePixelRatio,
    'stopwatch_frequency_hz': stopwatchFrequency,
  };
}

final class GraphXBenchmarkDistribution {
  GraphXBenchmarkDistribution._({
    required this.p50Micros,
    required this.p95Micros,
    required this.minMicros,
    required this.maxMicros,
    required this.averageMicros,
  });

  factory GraphXBenchmarkDistribution.fromTicks(
    List<int> values,
    int frequency,
  ) {
    if (values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'must not be empty');
    }
    if (frequency <= 0) {
      throw ArgumentError.value(frequency, 'frequency', 'must be positive');
    }
    final sorted = List<int>.of(values);
    sorted.sort();

    int percentile(double percentile) {
      final index = ((sorted.length - 1) * percentile).ceil();
      return sorted[index.clamp(0, sorted.length - 1)];
    }

    var total = 0;
    for (final value in values) {
      total += value;
    }

    double toMicros(num ticks) => ticks * 1000000.0 / frequency;

    return GraphXBenchmarkDistribution._(
      p50Micros: toMicros(percentile(.50)),
      p95Micros: toMicros(percentile(.95)),
      minMicros: toMicros(sorted.first),
      maxMicros: toMicros(sorted.last),
      averageMicros: toMicros(total / values.length),
    );
  }

  final double p50Micros;
  final double p95Micros;
  final double minMicros;
  final double maxMicros;
  final double averageMicros;
}

final class GraphXBenchmarkHarness {
  GraphXBenchmarkHarness({
    this.warmups = 12,
    this.samples = 41,
    GraphXBenchmarkEnvironment? environment,
  }) : environment = environment ?? GraphXBenchmarkEnvironment.capture();

  final int warmups;
  final int samples;
  final GraphXBenchmarkEnvironment environment;

  void printHeader({required String suite}) {
    print(graphXBenchmarkSchema);
    print('suite=$suite');
    print('environment=${jsonEncode(environment.toJson())}');
    print('warmups=$warmups samples=$samples');
    if (environment.mode == 'debug') {
      print('WARNING debug mode is not suitable for performance comparison');
    }
    print('');
  }

  GraphXBenchmarkDistribution measureSync({
    required String suite,
    required String workload,
    required String metric,
    required int count,
    required int operations,
    required void Function() body,
    void Function()? beforeSample,
    void Function()? afterSample,
    int? warmupCount,
    int? sampleCount,
    Map<String, Object?> configuration = const <String, Object?>{},
  }) {
    final actualWarmups = warmupCount ?? warmups;
    final actualSamples = sampleCount ?? samples;
    for (var i = 0; i < actualWarmups; ++i) {
      beforeSample?.call();
      body();
      afterSample?.call();
    }

    final times = List<int>.filled(actualSamples, 0);
    for (var i = 0; i < actualSamples; ++i) {
      beforeSample?.call();
      final watch = Stopwatch();
      watch.start();
      body();
      watch.stop();
      times[i] = watch.elapsedTicks;
      afterSample?.call();
    }

    final distribution = GraphXBenchmarkDistribution.fromTicks(times, _stopwatchFrequency);
    _emit(
      suite: suite,
      workload: workload,
      metric: metric,
      count: count,
      operations: operations,
      warmups: actualWarmups,
      samples: actualSamples,
      distribution: distribution,
      configuration: configuration,
    );
    return distribution;
  }

  Future<GraphXBenchmarkDistribution> measureAsync({
    required String suite,
    required String workload,
    required String metric,
    required int count,
    required int operations,
    required Future<void> Function() body,
    void Function()? beforeSample,
    void Function()? afterSample,
    int warmupCount = 2,
    int sampleCount = 21,
    Map<String, Object?> configuration = const <String, Object?>{},
  }) async {
    for (var i = 0; i < warmupCount; ++i) {
      beforeSample?.call();
      await body();
      afterSample?.call();
    }

    final times = List<int>.filled(sampleCount, 0);
    for (var i = 0; i < sampleCount; ++i) {
      beforeSample?.call();
      final watch = Stopwatch();
      watch.start();
      await body();
      watch.stop();
      times[i] = watch.elapsedTicks;
      afterSample?.call();
    }

    final distribution = GraphXBenchmarkDistribution.fromTicks(times, _stopwatchFrequency);
    _emit(
      suite: suite,
      workload: workload,
      metric: metric,
      count: count,
      operations: operations,
      warmups: warmupCount,
      samples: sampleCount,
      distribution: distribution,
      configuration: configuration,
    );
    return distribution;
  }

  void _emit({
    required String suite,
    required String workload,
    required String metric,
    required int count,
    required int operations,
    required int warmups,
    required int samples,
    required GraphXBenchmarkDistribution distribution,
    required Map<String, Object?> configuration,
  }) {
    final p50Ms = distribution.p50Micros / 1000.0;
    final p95Ms = distribution.p95Micros / 1000.0;
    final nsPerOperation = operations == 0 ? null : distribution.p50Micros * 1000.0 / operations;
    final perOperation = nsPerOperation == null
        ? ''
        : '  ${nsPerOperation.toStringAsFixed(1)} ns/op';
    print(
      '${workload.padRight(30)} ${metric.padRight(14)} '
      'p50 ${p50Ms.toStringAsFixed(3).padLeft(8)} ms  '
      'p95 ${p95Ms.toStringAsFixed(3).padLeft(8)} ms$perOperation',
    );

    final result = <String, Object?>{
      'schema': graphXBenchmarkSchema,
      'suite': suite,
      'workload': workload,
      'metric': metric,
      'count': count,
      'operations': operations,
      'warmups': warmups,
      'samples': samples,
      'p50_us': distribution.p50Micros,
      'p95_us': distribution.p95Micros,
      'min_us': distribution.minMicros,
      'max_us': distribution.maxMicros,
      'average_us': distribution.averageMicros,
      'p50_ns_per_operation': nsPerOperation,
      'environment': environment.toJson(),
      'configuration': configuration,
    };
    print('GRAPHX_BENCHMARK_RESULT ${jsonEncode(result)}');
  }
}
