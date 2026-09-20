// Copyright (c) 2026 GraphX by roipeker.

import 'package:flutter/widgets.dart';

import 'performance/baseline_suites.dart';
import 'performance/benchmark_harness.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  await Future<void>.delayed(const Duration(seconds: 3));
  final harness = GraphXBenchmarkHarness();
  await runGraphXPerformanceBaseline(harness);
}
