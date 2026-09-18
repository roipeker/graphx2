part of 'package:graphx/src/graphx_impl.dart';

final _GInspectorResourcesRuntime _gInspectorResourcesRuntime =
    _GInspectorResourcesRuntime();

/// Demand-driven runtime resource inspection.
///
/// This intentionally reads existing ownership state instead of maintaining a
/// second registry. Nothing is tracked per frame or per resource for DevTools.
final class _GInspectorResourcesRuntime {
  static const _prefix = 'ext.graphx.inspector';

  final Expando<String> _runtimeIds = Expando<String>(
    'graphx.inspector.runtimeId',
  );
  int _nextRuntimeId = 1;
  bool _registered = false;

  void ensureRegistered() {
    assert(!kReleaseMode);
    if (_registered) return;
    _registered = true;
    developer.registerExtension('$_prefix.listResources', _handleListResources);
  }

  Future<developer.ServiceExtensionResponse> _handleListResources(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _gInspectorRuntime._requireStage(parameters['stageId']);
      final runtime = stage._runtime;
      final stages = <GStage>[
        for (final candidate in _gInspectorRuntime._liveStages())
          if (identical(candidate._runtime, runtime)) candidate,
      ];
      final entries = runtime.assets._entries.entries.toList(growable: false);
      final resources =
          <Map<String, Object?>>[
            for (final entry in entries) _assetSummary(entry.key, entry.value),
          ]..sort((a, b) {
            final aBytes = a['estimatedBytes'] as int? ?? 0;
            final bBytes = b['estimatedBytes'] as int? ?? 0;
            final byBytes = bBytes.compareTo(aBytes);
            if (byBytes != 0) return byBytes;
            return '${a['key']}'.compareTo('${b['key']}');
          });

      var resolved = 0;
      var loading = 0;
      var summedEntryBytes = 0;
      for (final resource in resources) {
        if (resource['state'] == 'resolved') {
          resolved++;
        } else {
          loading++;
        }
        summedEntryBytes += resource['estimatedBytes'] as int? ?? 0;
      }

      return _gInspectorRuntime._result(<String, Object?>{
        'runtimeId': _idForRuntime(runtime),
        'stageIds': <String>[
          for (final candidate in stages)
            _gInspectorRuntime._idForStage(candidate),
        ],
        'assets': resources,
        'totals': <String, Object>{
          'entries': resources.length,
          'resolved': resolved,
          'loading': loading,
          'summedEntryBytes': summedEntryBytes,
        },
        'rasterCaches': <Object>[
          for (final candidate in stages)
            <String, Object>{
              'stageId': _gInspectorRuntime._idForStage(candidate),
              'count': candidate._rasterCacheCount,
              'retainedBytes': candidate._rasterCacheBytes,
            },
        ],
        'byteAccounting':
            'estimatedBytes is an inspection estimate. summedEntryBytes may '
            'double-count backing storage shared by separate asset entries.',
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  String _idForRuntime(GRuntime runtime) {
    final existing = _runtimeIds[runtime];
    if (existing != null) return existing;
    final id = 'r${_nextRuntimeId++}';
    _runtimeIds[runtime] = id;
    return id;
  }

  Map<String, Object?> _assetSummary(Object key, _GAssetEntry entry) {
    final value = entry.value;
    if (value == null) {
      return <String, Object?>{
        'key': '$key',
        'keyType': key.runtimeType.toString(),
        'state': 'loading',
        'kind': 'pending',
        'type': null,
        'estimatedBytes': 0,
      };
    }

    final common = <String, Object?>{
      'key': '$key',
      'keyType': key.runtimeType.toString(),
      'state': 'resolved',
      'kind': _kind(value),
      'type': value.runtimeType.toString(),
      'objectId': _gInspectorRuntime._idForObject(value),
      'disposed': value is _GDisposable ? value.isDisposed : null,
      'estimatedBytes': _estimatedBytes(value),
    };

    return switch (value) {
      GTexture texture => <String, Object?>{
        ...common,
        'width': texture.width,
        'height': texture.height,
        'backingWidth': texture.image.width,
        'backingHeight': texture.image.height,
        'backingId': _gInspectorRuntime._idForObject(texture.image),
        'scale': texture.scale,
        'ownsBacking': texture.ownsImage,
        'region': <String, Object?>{
          'x': texture.frame.region.x,
          'y': texture.frame.region.y,
          'width': texture.frame.region.w,
          'height': texture.frame.region.h,
          'rotated': texture.frame.rotated,
        },
      },
      GTextureSequence sequence => <String, Object?>{
        ...common,
        'width': sequence.width,
        'height': sequence.height,
        'frames': sequence.frameCount,
        'durationMicros': sequence.duration.inMicroseconds,
        'ownsTextures': sequence.ownsTextures,
        'backingIds': <String>[
          for (final image in _uniqueImages(sequence))
            _gInspectorRuntime._idForObject(image),
        ],
      },
      Uint8List bytes => <String, Object?>{
        ...common,
        'lengthInBytes': bytes.lengthInBytes,
      },
      _ => common,
    };
  }

  String _kind(Object value) => switch (value) {
    GTexture() => 'texture',
    GTextureSequence() => 'texture-sequence',
    Uint8List() => 'bytes',
    _GDisposable() => 'disposable',
    _ => 'object',
  };

  int _estimatedBytes(Object value) => switch (value) {
    GTexture texture => texture.image.width * texture.image.height * 4,
    GTextureSequence sequence => _sequenceBytes(sequence),
    Uint8List bytes => bytes.lengthInBytes,
    _ => 0,
  };

  int _sequenceBytes(GTextureSequence sequence) {
    var bytes = 0;
    for (final image in _uniqueImages(sequence)) {
      bytes += image.width * image.height * 4;
    }
    return bytes;
  }

  Set<ui.Image> _uniqueImages(GTextureSequence sequence) {
    final images = Set<ui.Image>.identity();
    for (final frame in sequence.frames) {
      images.add(frame.texture.image);
    }
    return images;
  }
}
