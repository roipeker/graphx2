// ignore_for_file: avoid_print

import 'dart:developer' as developer;
import 'dart:isolate' as isolate;

import 'package:flutter/widgets.dart';
import 'package:graphx/graphx.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final root = GRoot()..name = 'inspector-activity-root';
  final stage = GStage(root)
    ..mount()
    ..setViewport(320, 240);

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
              (value['root']! as Map)['name'] == 'inspector-activity-root',
        );
    final stageId = stageJson['id']! as String;

    final enabled = await _call(
      service,
      isolateId,
      'setActivityCapture',
      <String, dynamic>{
        'stageId': stageId,
        'enabled': 'true',
        'clear': 'true',
        'capacity': '8',
      },
    );
    final enabledState = Map<String, dynamic>.from(enabled['activity']! as Map);
    _check(enabledState['enabled'] == true, 'activity capture must enable');
    _check(enabledState['capacity'] == 8, 'activity capacity mismatch');
    _check(enabledState['retained'] == 0, 'new capture must start empty');

    final read = await _call(
      service,
      isolateId,
      'getActivity',
      <String, dynamic>{'stageId': stageId, 'after': '0', 'limit': '4'},
    );
    _check(read['limit'] == 4, 'activity read limit mismatch');
    _check((read['events']! as List).isEmpty, 'idle capture must be empty');

    final disabled = await _call(
      service,
      isolateId,
      'setActivityCapture',
      <String, dynamic>{
        'stageId': stageId,
        'enabled': 'false',
        'clear': 'false',
      },
    );
    final disabledState = Map<String, dynamic>.from(
      disabled['activity']! as Map,
    );
    _check(disabledState['enabled'] == false, 'activity capture must disable');

    print('PASS inspector activity enable/read/disable');
  } finally {
    await service?.dispose();
    stage.dispose();
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
