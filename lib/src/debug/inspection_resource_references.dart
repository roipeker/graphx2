part of 'package:graphx/graphx.dart';

final _GInspectorResourceReferencesRuntime
_gInspectorResourceReferencesRuntime = _GInspectorResourceReferencesRuntime();

/// Demand-driven resource references for one selected scene node.
///
/// This is intentionally separate from [GAssets] ownership inventory. A node can
/// retain textures or image backings directly even when the Stage runtime owns no
/// corresponding asset key. The query never scans the scene tree: it only reads
/// the selected node's authoritative retained references when explicitly asked.
final class _GInspectorResourceReferencesRuntime {
  static const _prefix = 'ext.graphx.inspector';

  bool _registered = false;

  void ensureRegistered() {
    assert(!kReleaseMode);
    if (_registered) return;
    _registered = true;
    developer.registerExtension(
      '$_prefix.inspectResourceReferences',
      _handleInspectResourceReferences,
    );
  }

  Future<developer.ServiceExtensionResponse> _handleInspectResourceReferences(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final node = _gInspectorRuntime._requireNode(parameters['nodeId']);
      return _gInspectorRuntime._result(<String, Object?>{
        'resourceReferences': _inspectNode(node),
      });
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._notFound(error.message);
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Map<String, Object?> _inspectNode(GNode node) {
    return switch (node) {
      GImage image => _inspectImage(image),
      GImageBatch batch => _inspectImageBatch(batch),
      _ => <String, Object?>{
        'nodeId': _gInspectorRuntime._idForObject(node),
        'nodeType': node.runtimeType.toString(),
        'supported': false,
        'summary':
            'No direct texture/backing resource adapter exists for this node type.',
        'referenceKind': 'direct-reference',
        'resources': const <Object>[],
      },
    };
  }

  Map<String, Object?> _inspectImage(GImage image) {
    final texture = image.texture;
    if (texture == null) {
      return <String, Object?>{
        'nodeId': _gInspectorRuntime._idForObject(image),
        'nodeType': image.runtimeType.toString(),
        'supported': true,
        'referenceKind': 'direct-reference',
        'instanceCount': 0,
        'textureCount': 0,
        'backingCount': 0,
        'estimatedBackingBytes': 0,
        'summary': 'GImage currently has no texture reference.',
        'resources': const <Object>[],
      };
    }
    final backing = texture.image;
    return <String, Object?>{
      'nodeId': _gInspectorRuntime._idForObject(image),
      'nodeType': image.runtimeType.toString(),
      'supported': true,
      'referenceKind': 'direct-reference',
      'instanceCount': 1,
      'textureCount': 1,
      'backingCount': 1,
      'estimatedBackingBytes': backing.width * backing.height * 4,
      'summary':
          'GImage directly references one GTexture. This is scene-reference state, not proof of GAssets ownership.',
      'resources': <Object>[
        _backingSummary(
          backing,
          textureRefs: 1,
          instanceRefs: 1,
          sampleTexture: texture,
        ),
      ],
    };
  }

  Map<String, Object?> _inspectImageBatch(GImageBatch batch) {
    final textures = Set<GTexture>.identity();
    final backingInstances = <ui.Image, int>{};

    for (var i = 0; i < batch._count; ++i) {
      final texture = batch._textures[i];
      if (texture == null) continue;
      textures.add(texture);
      backingInstances.update(
        texture.image,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final backingTextureCounts = <ui.Image, int>{};
    final sampleTextures = <ui.Image, GTexture>{};
    for (final texture in textures) {
      final image = texture.image;
      backingTextureCounts.update(
        image,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      sampleTextures.putIfAbsent(image, () => texture);
    }

    var estimatedBytes = 0;
    final resources = <Object>[];
    for (final entry in backingInstances.entries) {
      final image = entry.key;
      final bytes = image.width * image.height * 4;
      estimatedBytes += bytes;
      resources.add(
        _backingSummary(
          image,
          textureRefs: backingTextureCounts[image] ?? 0,
          instanceRefs: entry.value,
          sampleTexture: sampleTextures[image],
        ),
      );
    }
    resources.sort((a, b) {
      final aa = a as Map<String, Object?>;
      final bb = b as Map<String, Object?>;
      return (bb['estimatedBytes'] as int).compareTo(
        aa['estimatedBytes'] as int,
      );
    });

    return <String, Object?>{
      'nodeId': _gInspectorRuntime._idForObject(batch),
      'nodeType': batch.runtimeType.toString(),
      'supported': true,
      'referenceKind': 'direct-reference',
      'instanceCount': batch._count,
      'textureCount': textures.length,
      'backingCount': backingInstances.length,
      'estimatedBackingBytes': estimatedBytes,
      'summary': batch._count == 0
          ? 'GImageBatch currently has no active texture references.'
          : 'GImageBatch directly retains textures for its active instances. Backing bytes are deduplicated by image identity for this selected batch only; this is not GAssets ownership or process/GPU memory.',
      'resources': resources,
    };
  }

  Map<String, Object?> _backingSummary(
    ui.Image image, {
    required int textureRefs,
    required int instanceRefs,
    GTexture? sampleTexture,
  }) {
    final region = sampleTexture?.frame.region;
    return <String, Object?>{
      'id': _gInspectorRuntime._idForObject(image),
      'kind': 'image-backing',
      'type': image.runtimeType.toString(),
      'label': 'Image ${image.width}×${image.height}',
      'width': image.width,
      'height': image.height,
      'estimatedBytes': image.width * image.height * 4,
      'textureRefs': textureRefs,
      'instanceRefs': instanceRefs,
      'sampleTextureId': sampleTexture == null
          ? null
          : _gInspectorRuntime._idForObject(sampleTexture),
      'sampleOwnsBacking': sampleTexture?.ownsImage,
      'sampleRegion': region == null
          ? null
          : <String, Object?>{
              'x': region.x,
              'y': region.y,
              'width': region.w,
              'height': region.h,
              'rotated': sampleTexture!.frame.rotated,
            },
    };
  }
}
