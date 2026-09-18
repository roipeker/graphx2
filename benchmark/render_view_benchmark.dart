// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';
import 'package:graphx/graphx_extension.dart';

const _nodes = 20000;
const _samples = 15;
const _warmups = 5;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  print('GRAPHX RENDER VIEW SUITE');
  print('20K retained nodes · profile mode · PictureRecorder render traversal');
  print('');

  final flat = _buildFlatScene(_nodes);
  _report('legacy identity', flat, nodePasses: _nodes);

  flat.stage.renderViews.add(GRenderView(viewport: GRect(0, 0, 1280, 720)));
  _report('1 explicit identity', flat, nodePasses: _nodes);

  flat.stage.renderViews[0].transform.setValues(1.5, 0, 0, 1.5, -420, -210);
  flat.stage.renderViews[0].invalidate();
  _report('1 transformed view', flat, nodePasses: _nodes);

  flat.stage.renderViews
    ..clear()
    ..add(
      GRenderView(
        viewport: GRect(0, 0, 640, 720),
        transform: GMatrix2(1.2, 0, 0, 1.2, -120, -80),
      ),
    )
    ..add(
      GRenderView(
        viewport: GRect(640, 0, 640, 720),
        transform: GMatrix2(.8, 0, 0, .8, -40, 40),
      ),
    );
  _report('2 split views', flat, nodePasses: _nodes * 2);

  flat.stage.renderViews
    ..clear()
    ..add(GRenderView(viewport: GRect(0, 0, 640, 360)))
    ..add(GRenderView(viewport: GRect(640, 0, 640, 360)))
    ..add(GRenderView(viewport: GRect(0, 360, 640, 360)))
    ..add(GRenderView(viewport: GRect(640, 360, 640, 360)));
  _report('4 views', flat, nodePasses: _nodes * 4);
  flat.dispose();

  print('');

  final grouped = _buildGroupedScene(_nodes, groups: 4);
  grouped.stage.renderViews.add(
    GRenderView(viewport: GRect(0, 0, 1280, 720), mask: GRenderMask.bit(0)),
  );
  _report(
    'mask selects 1/4',
    grouped,
    nodePasses: _nodes ~/ 4,
    note: '3 groups rejected at boundary',
  );

  grouped.stage.renderViews[0].mask = GRenderMask.all;
  _report('mask all groups', grouped, nodePasses: _nodes);
  grouped.dispose();

  print('GRAPHX_BENCHMARK_COMPLETE');
  exit(0);
}

_BenchScene _buildFlatScene(int count) {
  final root = GRoot();
  final parent = root.addChild(GNode(name: 'flat'));
  for (var i = 0; i < count; ++i) {
    parent.addChild(GNode());
  }
  return _mount(root);
}

_BenchScene _buildGroupedScene(int count, {required int groups}) {
  final root = GRoot();
  final perGroup = count ~/ groups;
  for (var group = 0; group < groups; ++group) {
    final parent = root.addChild(
      GRenderGroup(mask: GRenderMask.bit(group), name: 'group-$group'),
    );
    for (var i = 0; i < perGroup; ++i) {
      parent.addChild(GNode());
    }
  }
  return _mount(root);
}

_BenchScene _mount(GRoot root) {
  final stage = GStage(root)
    ..mount()
    ..setViewport(1280, 720, devicePixelRatio: 1);
  return _BenchScene(stage, GCanvasRenderer());
}

final class _BenchScene {
  _BenchScene(this.stage, this.renderer);

  final GStage stage;
  final GCanvasRenderer renderer;

  void dispose() {
    renderer.dispose();
    stage.dispose();
  }
}

void _report(
  String label,
  _BenchScene scene, {
  required int nodePasses,
  String? note,
}) {
  for (var i = 0; i < _warmups; ++i) {
    _record(scene);
  }

  final samples = List<int>.filled(_samples, 0);
  for (var i = 0; i < samples.length; ++i) {
    final recorder = ui.PictureRecorder();
    final watch = Stopwatch()..start();
    scene.renderer.render(ui.Canvas(recorder), scene.stage);
    watch.stop();
    samples[i] = watch.elapsedMicroseconds;
    recorder.endRecording().dispose();
  }

  samples.sort();
  final p50 = samples[samples.length ~/ 2];
  final p95 =
      samples[(samples.length * .95).floor().clamp(0, samples.length - 1)];
  final nsPerPass = p50 * 1000 / nodePasses;
  final suffix = note == null ? '' : '  $note';
  print(
    '${label.padRight(22)} '
    'p50 ${(p50 / 1000).toStringAsFixed(3).padLeft(8)} ms  '
    'p95 ${(p95 / 1000).toStringAsFixed(3).padLeft(8)} ms  '
    '${nsPerPass.toStringAsFixed(1).padLeft(7)} ns/node-pass$suffix',
  );
}

void _record(_BenchScene scene) {
  final recorder = ui.PictureRecorder();
  scene.renderer.render(ui.Canvas(recorder), scene.stage);
  recorder.endRecording().dispose();
}
