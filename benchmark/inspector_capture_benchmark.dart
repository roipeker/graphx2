// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate' as isolate;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 160,
          height: 90,
          child: GraphxView(root: _buildRoot),
        ),
      ),
    ),
  );
  await SchedulerBinding.instance.endOfFrame;

  VmService? service;
  try {
    final serviceInfo = await developer.Service.getInfo();
    final wsUri = serviceInfo.serverWebSocketUri;
    _check(wsUri != null, 'VM service websocket must be available');

    service = await vmServiceConnectUri(wsUri.toString());
    final isolateId = developer.Service.getIsolateId(isolate.Isolate.current);
    _check(isolateId != null, 'current isolate ID must be available');

    final stages = await _call(service, isolateId!, 'listStages');
    final stageJson = (stages['stages']! as List)
        .cast<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .singleWhere(
          (value) =>
              (value['root']! as Map)['name'] == 'inspector-capture-root',
        );
    final stageId = stageJson['id']! as String;
    _check(stageJson['hosted'] == true, 'capture Stage must be Flutter hosted');

    final response = await _call(
      service,
      isolateId,
      'captureStageImage',
      <String, dynamic>{'stageId': stageId, 'scale': '0.5'},
    );
    final capture = Map<String, dynamic>.from(response['capture']! as Map);
    _check(capture['mimeType'] == 'image/png', 'capture MIME type mismatch');
    _check(capture['width'] == 80, 'capture width must honor scale');
    _check(capture['height'] == 45, 'capture height must honor scale');
    _check(capture['scale'] == 0.5, 'capture scale mismatch');
    _checkPng(capture);

    final root = Map<String, dynamic>.from(stageJson['root']! as Map);
    final children = await _call(
      service,
      isolateId,
      'getChildren',
      <String, dynamic>{'nodeId': root['id'], 'offset': 0, 'limit': 20},
    );
    final target = (children['children']! as List)
        .cast<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .singleWhere((value) => value['name'] == 'capture-target');

    final nodeResponse = await _call(
      service,
      isolateId,
      'captureStageImage',
      <String, dynamic>{
        'stageId': stageId,
        'nodeId': target['id'],
        'scale': 1,
        'padding': 4,
      },
    );
    final nodeCapture = Map<String, dynamic>.from(
      nodeResponse['capture']! as Map,
    );
    _check(nodeCapture['nodeId'] == target['id'], 'node capture ID mismatch');
    _check(nodeCapture['width'] == 58, 'node crop width must include padding');
    _check(
      nodeCapture['height'] == 38,
      'node crop height must include padding',
    );
    _check(nodeCapture['logicalX'] == 36.0, 'node crop x mismatch');
    _check(nodeCapture['logicalY'] == 16.0, 'node crop y mismatch');
    _check(
      nodeCapture['logicalWidth'] == 58.0,
      'node crop logical width mismatch',
    );
    _check(
      nodeCapture['logicalHeight'] == 38.0,
      'node crop logical height mismatch',
    );
    _check(nodeCapture['padding'] == 4.0, 'node capture padding mismatch');
    _checkPng(nodeCapture);

    print('PASS inspector hosted visual capture + node crop');
  } finally {
    await service?.dispose();
  }

  print('SATECHI_BENCHMARK_COMPLETE');
  exit(0);
}

GRoot _buildRoot() {
  final root = GRoot()..name = 'inspector-capture-root';
  final target = root.addChild(GShape('capture-target'));
  target
    ..setPosition(40, 20)
    ..graphics.beginFill(const Color(0xff66ccff))
    ..graphics.drawRect(0, 0, 50, 30)
    ..graphics.endFill();
  return root;
}

void _checkPng(Map<String, dynamic> capture) {
  final bytes = base64Decode(capture['base64']! as String);
  _check(bytes.length == capture['bytes'], 'capture byte count mismatch');
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  _check(bytes.length >= signature.length, 'capture PNG is unexpectedly short');
  for (var i = 0; i < signature.length; ++i) {
    _check(
      bytes[i] == signature[i],
      'capture PNG signature mismatch at byte $i',
    );
  }
}

Future<Map<String, dynamic>> _call(
  VmService service,
  String isolateId,
  String command, [
  Map<String, dynamic>? args,
]) async {
  final response = await service.callServiceExtension(
    'ext.graphx.inspector.$command',
    isolateId: isolateId,
    args: args?.map((key, value) => MapEntry(key, '$value')),
  );
  final json = response.json;
  if (json == null) throw StateError('$command returned no JSON');
  return Map<String, dynamic>.from(json);
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
