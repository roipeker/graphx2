// Copyright (c) 2026 GraphX by roipeker.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _operationCapabilities = <String, String>{
  'listStages': 'stages',
  'getChildren': 'tree.children',
  'getPath': 'tree.path',
  'inspectObject': 'object.inspect',
  'inspectNode': 'object.inspect',
  'pick': 'scene.pick',
  'setSelection': 'scene.highlight',
  'setPickMode': 'scene.picker',
  'getPickState': 'scene.picker',
  'commitPick': 'scene.picker',
  'diagnoseNode': 'node.diagnostics',
  'listResources': 'resources.inventory',
  'inspectResourceReferences': 'resources.references',
  'getRenderOverview': 'render.overview',
  'explainRender': 'render.explain',
  'setRenderInstrumentation': 'render.instrumentation',
  'setActivityCapture': 'activity.capture',
  'getActivity': 'activity.capture',
  'captureStageImage': 'visual.capture',
};

const _schemaCapabilities = <String>{
  'object.references',
  'object.source.creation',
};

void main() {
  test('getInfo advertises every registered inspector operation domain', () {
    final debugDirectory = Directory('${_packageRoot().path}/lib/src/debug/inspection');
    final registeredOperations = <String>{};
    final registrationPattern = RegExp(
      r"registerExtension\(\s*'\$_prefix\.([A-Za-z0-9]+)'",
      multiLine: true,
    );

    for (final entity in debugDirectory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final match in registrationPattern.allMatches(source)) {
        final operation = match.group(1)!;
        if (operation != 'getInfo') registeredOperations.add(operation);
      }
    }

    expect(
      registeredOperations,
      _operationCapabilities.keys.toSet(),
      reason:
          'Every inspector RPC must be assigned to one semantic capability. '
          'Update the contract when adding or removing an operation.',
    );

    final inspectionSource = File(
      '${debugDirectory.path}/runtime.dart',
    ).readAsStringSync();
    final capabilitiesBlock = RegExp(
      r"'capabilities': const <String>\[(.*?)\]",
      dotAll: true,
    ).firstMatch(inspectionSource);
    expect(capabilitiesBlock, isNotNull);

    final advertised = RegExp(
      r"'([^']+)'",
    ).allMatches(capabilitiesBlock!.group(1)!).map((match) => match.group(1)!).toSet();
    final expected = <String>{
      ..._operationCapabilities.values,
      ..._schemaCapabilities,
    };

    expect(
      advertised,
      expected,
      reason:
          'getInfo.capabilities is the authoritative protocol-v1 semantic '
          'capability set. Do not leave stale or undiscoverable domains.',
    );
  });
}

Directory _packageRoot() {
  final current = Directory.current.absolute;
  if (File('${current.path}/lib/graphx.dart').existsSync()) return current;

  final workspacePackage = Directory('${current.path}/packages/graphx');
  if (File('${workspacePackage.path}/lib/graphx.dart').existsSync()) {
    return workspacePackage;
  }

  throw StateError('Could not locate packages/graphx from ${current.path}.');
}
