// ignore_for_file: avoid_print

import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate' as isolate;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

const int _nodeCount = 100000;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('SATECHI INSPECTOR RPC + SCALE');
  print('$_nodeCount retained nodes · real VM-service extension calls');

  final root = GRoot()..name = 'inspector-scale-root';
  final probe = _ProbeNode('probe')
    ..x = 10
    ..y = 20;
  probe.filters = <GFilter>[GBlurFilter(blurX: 3, blurY: 5)];
  probe.cache;

  final holder = GNode('holder');
  root
    ..addChild(probe)
    ..addChild(holder);
  for (var i = 2; i < _nodeCount; ++i) {
    root.addChild(GNode('node-$i'));
  }

  final stage = GStage(root)
    ..mount()
    ..setViewport(1024, 768, devicePixelRatio: 1);
  stage.assets.set('inspector:bytes', Uint8List(64));

  VmService? service;
  try {
    final info = await developer.Service.getInfo();
    final wsUri = info.serverWebSocketUri;
    _check(wsUri != null, 'profile app must expose a VM-service websocket');

    service = await vmServiceConnectUri(wsUri.toString());
    final isolateId = developer.Service.getIsolateId(isolate.Isolate.current);
    _check(isolateId != null, 'current isolate id must be available');

    final serviceInfo = await _call(service, isolateId!, 'getInfo');
    _check(serviceInfo['protocolVersion'] == 1, 'protocol version must be 1');
    final capabilities = (serviceInfo['capabilities']! as List).cast<String>();
    _check(
      capabilities.contains('object.inspect'),
      'object inspection missing',
    );
    _check(
      capabilities.contains('object.references'),
      'object references missing',
    );

    final listWatch = Stopwatch()..start();
    final stages = await _call(service, isolateId, 'listStages');
    listWatch.stop();
    final stageJson = (stages['stages']! as List)
        .cast<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .singleWhere(
          (value) => (value['root']! as Map)['name'] == 'inspector-scale-root',
        );
    _check(
      stageJson['nodeCount'] == _nodeCount + 1,
      'stage node count must include the root',
    );
    final stageId = stageJson['id']! as String;
    final rootJson = Map<String, dynamic>.from(stageJson['root']! as Map);
    final rootId = rootJson['id']! as String;

    final resourceWatch = Stopwatch()..start();
    final resourceState = await _call(
      service,
      isolateId,
      'listResources',
      <String, dynamic>{'stageId': stageId},
    );
    resourceWatch.stop();
    final resourceStageIds = (resourceState['stageIds']! as List)
        .cast<String>();
    _check(
      resourceStageIds.contains(stageId),
      'resource runtime must include stage',
    );
    final resourceAssets = (resourceState['assets']! as List)
        .cast<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
    final resourceBytes = resourceAssets.singleWhere(
      (value) => value['key'] == 'inspector:bytes',
    );
    _check(resourceBytes['kind'] == 'bytes', 'resource kind mismatch');
    _check(
      resourceBytes['estimatedBytes'] == 64,
      'resource byte estimate mismatch',
    );
    _check(
      resourceBytes['lengthInBytes'] == 64,
      'resource byte length mismatch',
    );
    final cacheTotals = (resourceState['rasterCaches']! as List).cast<Map>();
    _check(cacheTotals.length == 1, 'resource cache stage aggregate mismatch');
    _check(
      cacheTotals.single['stageId'] == stageId,
      'resource cache owner mismatch',
    );

    final pageWatch = Stopwatch()..start();
    final page = await _call(
      service,
      isolateId,
      'getChildren',
      <String, dynamic>{'nodeId': rootId, 'offset': '0', 'limit': '3'},
    );
    pageWatch.stop();
    _check(page['total'] == _nodeCount, 'paged child total mismatch');
    final children = (page['children']! as List)
        .cast<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
    _check(
      children.length == 3,
      'page must materialize only requested children',
    );
    _check(children.first['name'] == 'probe', 'probe must be first child');
    _check(children[1]['name'] == 'holder', 'holder must be second child');

    final probeId = children.first['id']! as String;
    final holderId = children[1]['id']! as String;
    final movableId = children[2]['id']! as String;

    final inspectWatch = Stopwatch()..start();
    final inspected = await _call(
      service,
      isolateId,
      'inspectObject',
      <String, dynamic>{'objectId': probeId},
    );
    inspectWatch.stop();
    final node = Map<String, dynamic>.from(inspected['object']! as Map);
    _check(node['kind'] == 'node', 'probe must inspect as node');
    _check(
      (node['transform']! as Map)['x'] == 10.0,
      'probe transform mismatch',
    );

    final references = (node['references']! as List)
        .cast<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
    final filterRef = references.singleWhere(
      (value) => value['relation'] == 'filter',
    );
    final cacheRef = references.singleWhere(
      (value) => value['relation'] == 'cache',
    );

    final filterResult = await _call(
      service,
      isolateId,
      'inspectObject',
      <String, dynamic>{'objectId': filterRef['id']},
    );
    final filter = Map<String, dynamic>.from(filterResult['object']! as Map);
    _check(filter['kind'] == 'filter', 'filter reference must be inspectable');
    _check(filter['ownerId'] == probeId, 'filter owner link mismatch');
    _check(
      (filter['properties']! as Map)['blurX'] == 3.0,
      'filter property mismatch',
    );

    final cacheResult = await _call(
      service,
      isolateId,
      'inspectObject',
      <String, dynamic>{'objectId': cacheRef['id']},
    );
    final cache = Map<String, dynamic>.from(cacheResult['object']! as Map);
    _check(cache['kind'] == 'cache', 'cache reference must be inspectable');
    _check(cache['ownerId'] == probeId, 'cache owner link mismatch');

    final picked = await _call(service, isolateId, 'pick', <String, dynamic>{
      'stageId': stageId,
      'x': '15',
      'y': '25',
    });
    final pickedPath = picked['path']! as List;
    _check((pickedPath.last as Map)['id'] == probeId, 'scene pick mismatch');

    await _call(service, isolateId, 'setSelection', <String, dynamic>{
      'stageId': stageId,
      'nodeId': probeId,
      'enabled': 'true',
    });

    final movable = root.getChildAt(2);
    holder.addChild(movable);
    final holderChildren = await _call(
      service,
      isolateId,
      'getChildren',
      <String, dynamic>{'nodeId': holderId, 'offset': '0', 'limit': '10'},
    );
    _check(
      ((holderChildren['children']! as List).single as Map)['id'] == movableId,
      'reparenting must preserve inspector identity',
    );

    movable.dispose();
    var staleRejected = false;
    try {
      await service.callServiceExtension(
        'ext.graphx.inspector.inspectObject',
        isolateId: isolateId,
        args: <String, dynamic>{'objectId': movableId},
      );
    } on RPCError {
      staleRejected = true;
    }
    _check(staleRejected, 'disposed object id must become stale');

    await _call(service, isolateId, 'setSelection', <String, dynamic>{
      'stageId': stageId,
      'nodeId': '',
      'enabled': 'false',
    });

    print(
      'listStages ${listWatch.elapsedMicroseconds} us · '
      'listResources ${resourceWatch.elapsedMicroseconds} us · '
      'getChildren(3/$_nodeCount) ${pageWatch.elapsedMicroseconds} us · '
      'inspectObject ${inspectWatch.elapsedMicroseconds} us',
    );
    print('resources: runtime assets + cache aggregate PASS');
    print('object graph: node -> filter/cache -> owner PASS');
    print('reparent identity + stale-id rejection + pick/selection PASS');
  } finally {
    service?.dispose();
    stage.dispose();
  }

  print('SATECHI_BENCHMARK_COMPLETE');
  exit(0);
}

Future<Map<String, dynamic>> _call(
  VmService service,
  String isolateId,
  String method, [
  Map<String, dynamic>? args,
]) async {
  final response = await service.callServiceExtension(
    'ext.graphx.inspector.$method',
    isolateId: isolateId,
    args: args,
  );
  final json = response.json;
  _check(json != null, '$method returned an empty response');
  return Map<String, dynamic>.from(json!);
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _ProbeNode extends GNode {
  _ProbeNode([super.name]);

  @override
  void computeSelfBounds(GBounds out) => out.set(0, 0, 10, 10);
}
