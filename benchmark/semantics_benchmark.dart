// Copyright (c) 2026 GraphX by roipeker.

// ignore_for_file: avoid_print

import 'dart:io' as io;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';

const _nodeCount = 100000;
double _sink = 0.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final root = GRoot();
  final nodes = List<GNode>.generate(_nodeCount, (index) {
    final node = GNode(name: 'n$index');
    root.addChild(node);
    return node;
  }, growable: false);
  final stage = GStage(root)..mount();
  stage.setViewport(1920, 1080);

  print('graphx semantics benchmark');
  print(
    'Run with: flutter run -d macos --profile benchmark/semantics_benchmark.dart',
  );
  print('$_nodeCount retained GNodes · median of 7 measured passes');
  print('');

  _reportMutations('transform · no semantics', nodes);

  nodes.last.semantics
    ..label = 'Sparse semantic node'
    ..role = GSemanticsRole.button;
  _reportMutations('transform · 1 semantic', nodes);

  for (final count in const <int>[10, 100, 1000]) {
    final semanticNodes = nodes.take(count).toList(growable: false);
    for (var i = 0; i < semanticNodes.length; ++i) {
      semanticNodes[i].semantics
        ..label = 'semantic $i'
        ..role = GSemanticsRole.toggle
        ..toggled = false;
    }
    _reportSemanticUpdates('state update · $count', semanticNodes);
  }

  stage.dispose();
  if (_sink == double.negativeInfinity) print(_sink);
  await io.stdout.flush();
  io.exit(0);
}

void _reportMutations(String label, List<GNode> nodes) {
  void run() {
    var total = 0.0;
    for (var i = 0; i < nodes.length; ++i) {
      final node = nodes[i];
      node.x += 0.125;
      total += node.x;
    }
    _sink = total;
  }

  for (var i = 0; i < 2; ++i) run();
  final samples = List<int>.filled(7, 0);
  for (var i = 0; i < samples.length; ++i) {
    final watch = Stopwatch()..start();
    run();
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
  }
  samples.sort();
  final us = samples[samples.length ~/ 2];
  final nsPerMutation = us * 1000.0 / nodes.length;
  print(
    '${label.padRight(27)} ${(us / 1000).toStringAsFixed(3).padLeft(9)} ms  '
    '${nsPerMutation.toStringAsFixed(2).padLeft(8)} ns/mutation',
  );
}

void _reportSemanticUpdates(String label, List<GNode> nodes) {
  var value = false;
  void run() {
    value = !value;
    for (var i = 0; i < nodes.length; ++i) {
      nodes[i].semantics.toggled = value;
    }
  }

  for (var i = 0; i < 2; ++i) run();
  final samples = List<int>.filled(7, 0);
  for (var i = 0; i < samples.length; ++i) {
    final watch = Stopwatch()..start();
    run();
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
  }
  samples.sort();
  final us = samples[samples.length ~/ 2];
  final nsPerNode = us * 1000.0 / nodes.length;
  print(
    '${label.padRight(27)} ${(us / 1000).toStringAsFixed(3).padLeft(9)} ms  '
    '${nsPerNode.toStringAsFixed(2).padLeft(8)} ns/node',
  );
}
