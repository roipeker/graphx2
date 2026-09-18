part of 'package:graphx/graphx.dart';

final _GInspectorCaptureRuntime _gInspectorCaptureRuntime =
    _GInspectorCaptureRuntime();

/// Explicit live visual evidence for tooling.
///
/// Context capture reuses [GStage.snapshot], so it represents the final
/// GraphxView composition including rasterizable Flutter portals. Isolated node
/// capture reuses [GNodeSnapshot.snapshot] and renders only that node subtree.
/// No capture state or readback work exists until a client invokes the service
/// extension.
final class _GInspectorCaptureRuntime {
  static const _prefix = 'ext.graphx.inspector';
  static const _maxPixels = 4 * 1024 * 1024;
  static const _maxPngBytes = 8 * 1024 * 1024;

  bool _registered = false;

  void registerStage(GStage stage) {
    assert(!kReleaseMode);
    _ensureRegistered();
  }

  void _ensureRegistered() {
    if (_registered) return;
    _registered = true;
    developer.registerExtension(
      '$_prefix.captureStageImage',
      _handleCaptureStageImage,
    );
  }

  Future<developer.ServiceExtensionResponse> _handleCaptureStageImage(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final stage = _gInspectorRuntime._requireStage(parameters['stageId']);
      if (!stage.isHosted) {
        return _gInspectorRuntime._invalidParams(
          'Visual capture requires a Flutter-hosted Stage.',
        );
      }
      if (!stage.width.isFinite ||
          !stage.height.isFinite ||
          stage.width <= 0.0 ||
          stage.height <= 0.0) {
        return _gInspectorRuntime._invalidParams(
          'Visual capture requires a Stage with a usable viewport.',
        );
      }

      final scaleText = parameters['scale'];
      final scale = scaleText == null || scaleText.isEmpty
          ? 1.0
          : double.tryParse(scaleText);
      if (scale == null || !scale.isFinite || scale <= 0.0) {
        return _gInspectorRuntime._invalidParams(
          'scale must be a finite number greater than zero.',
        );
      }

      final paddingText = parameters['padding'];
      final padding = paddingText == null || paddingText.isEmpty
          ? 0.0
          : double.tryParse(paddingText);
      if (padding == null || !padding.isFinite || padding < 0.0) {
        return _gInspectorRuntime._invalidParams(
          'padding must be a finite number greater than or equal to zero.',
        );
      }

      final mode = parameters['mode'] ?? 'context';
      if (mode != 'context' && mode != 'isolated') {
        return _gInspectorRuntime._invalidParams(
          'mode must be context or isolated.',
        );
      }

      final nodeId = parameters['nodeId'];
      GNode? node;
      if (nodeId != null && nodeId.isNotEmpty) {
        node = _gInspectorRuntime._requireNode(nodeId);
        if (!identical(node._stage, stage) || !node.isAttached) {
          return _gInspectorRuntime._invalidParams(
            'Captured node does not belong to the selected Stage.',
          );
        }
      } else if (mode == 'isolated') {
        return _gInspectorRuntime._invalidParams(
          'Isolated capture requires nodeId.',
        );
      }

      final frame = stage.frame;
      if (mode == 'isolated') {
        return await _captureIsolated(
          stage,
          node!,
          frame: frame,
          scale: scale,
          padding: padding,
        );
      }
      return await _captureContext(
        stage,
        node,
        frame: frame,
        scale: scale,
        padding: padding,
      );
    } on FormatException catch (error) {
      return _gInspectorRuntime._invalidParams(error.message);
    } on StateError catch (error) {
      return _gInspectorRuntime._extensionError(error);
    } on ArgumentError catch (error) {
      return _gInspectorRuntime._invalidParams('$error');
    } catch (error) {
      return _gInspectorRuntime._extensionError(error);
    }
  }

  Future<developer.ServiceExtensionResponse> _captureContext(
    GStage stage,
    GNode? node, {
    required int frame,
    required double scale,
    required double padding,
  }) async {
    var logicalRect = ui.Rect.fromLTWH(0.0, 0.0, stage.width, stage.height);
    if (node != null) {
      logicalRect = _nodeStageVisualBounds(
        node,
        padding: padding,
      ).intersect(ui.Rect.fromLTWH(0.0, 0.0, stage.width, stage.height));
      if (!_usableRect(logicalRect)) {
        return _gInspectorRuntime._invalidParams(
          'Captured node has no visible bounds inside the Stage viewport.',
        );
      }
    }

    final pixelLeft = math.max(0, (logicalRect.left * scale).floor());
    final pixelTop = math.max(0, (logicalRect.top * scale).floor());
    final pixelRight = math.min(
      (stage.width * scale).ceil(),
      (logicalRect.right * scale).ceil(),
    );
    final pixelBottom = math.min(
      (stage.height * scale).ceil(),
      (logicalRect.bottom * scale).ceil(),
    );
    final pixelWidth = math.max(1, pixelRight - pixelLeft);
    final pixelHeight = math.max(1, pixelBottom - pixelTop);
    final limitError = _pixelLimitError(pixelWidth, pixelHeight);
    if (limitError != null)
      return _gInspectorRuntime._invalidParams(limitError);

    final texture = await stage.snapshot(scale: scale);
    ui.Image? cropped;
    try {
      final source = texture.image;
      final image =
          node == null &&
              pixelLeft == 0 &&
              pixelTop == 0 &&
              pixelWidth == source.width &&
              pixelHeight == source.height
          ? source
          : await _cropImage(
              source,
              left: pixelLeft,
              top: pixelTop,
              width: pixelWidth,
              height: pixelHeight,
            );
      if (!identical(image, source)) cropped = image;
      return await _encode(
        stage,
        node,
        image,
        frame: frame,
        mode: 'context',
        coordinateSpace: 'stage',
        logicalX: logicalRect.left,
        logicalY: logicalRect.top,
        logicalWidth: logicalRect.width,
        logicalHeight: logicalRect.height,
        scale: scale,
        padding: node == null ? 0.0 : padding,
      );
    } finally {
      cropped?.dispose();
      texture.dispose();
    }
  }

  Future<developer.ServiceExtensionResponse> _captureIsolated(
    GStage stage,
    GNode node, {
    required int frame,
    required double scale,
    required double padding,
  }) async {
    final effect = node.getEffectBounds();
    if (effect.isEmpty) {
      return _gInspectorRuntime._invalidParams(
        'Captured node has empty rendered bounds.',
      );
    }
    final area = GRect(
      effect.x1 - padding,
      effect.y1 - padding,
      effect.width + padding * 2.0,
      effect.height + padding * 2.0,
    );
    final pixelWidth = math.max(1, (area.w * scale).ceil());
    final pixelHeight = math.max(1, (area.h * scale).ceil());
    final limitError = _pixelLimitError(pixelWidth, pixelHeight);
    if (limitError != null)
      return _gInspectorRuntime._invalidParams(limitError);

    final texture = await node.snapshot(area: area, scale: scale);
    try {
      return await _encode(
        stage,
        node,
        texture.image,
        frame: frame,
        mode: 'isolated',
        coordinateSpace: 'node-local',
        logicalX: area.x,
        logicalY: area.y,
        logicalWidth: area.w,
        logicalHeight: area.h,
        scale: scale,
        padding: padding,
      );
    } finally {
      texture.dispose();
    }
  }

  Future<developer.ServiceExtensionResponse> _encode(
    GStage stage,
    GNode? node,
    ui.Image image, {
    required int frame,
    required String mode,
    required String coordinateSpace,
    required double logicalX,
    required double logicalY,
    required double logicalWidth,
    required double logicalHeight,
    required double scale,
    required double padding,
  }) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not encode the capture as PNG.');
    if (data.lengthInBytes > _maxPngBytes) {
      throw StateError(
        'Encoded PNG is ${data.lengthInBytes} bytes; the tooling limit is '
        '$_maxPngBytes bytes. Reduce scale.',
      );
    }
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return _gInspectorRuntime._result(<String, Object?>{
      'capture': <String, Object?>{
        'stageId': _gInspectorRuntime._idForStage(stage),
        if (node != null) 'nodeId': _gInspectorRuntime._idForObject(node),
        'frame': frame,
        'mode': mode,
        'coordinateSpace': coordinateSpace,
        'mimeType': 'image/png',
        'width': image.width,
        'height': image.height,
        'logicalX': logicalX,
        'logicalY': logicalY,
        'logicalWidth': logicalWidth,
        'logicalHeight': logicalHeight,
        'scale': scale,
        'padding': padding,
        'bytes': bytes.lengthInBytes,
        'base64': base64Encode(bytes),
      },
    });
  }

  String? _pixelLimitError(int width, int height) {
    final pixels = width * height;
    if (pixels <= _maxPixels) return null;
    return 'Requested capture is $width×$height ($pixels pixels); '
        'the tooling limit is $_maxPixels pixels. Reduce scale.';
  }

  bool _usableRect(ui.Rect rect) =>
      !rect.isEmpty &&
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;

  ui.Rect _nodeStageVisualBounds(GNode node, {required double padding}) {
    final bounds = node.getEffectBounds();
    if (bounds.isEmpty) return ui.Rect.zero;

    final p0 = GPoint();
    final p1 = GPoint();
    final p2 = GPoint();
    final p3 = GPoint();
    node.localToGlobalInto(bounds.x1, bounds.y1, p0);
    node.localToGlobalInto(bounds.x2, bounds.y1, p1);
    node.localToGlobalInto(bounds.x2, bounds.y2, p2);
    node.localToGlobalInto(bounds.x1, bounds.y2, p3);

    final left = math.min(math.min(p0.x, p1.x), math.min(p2.x, p3.x)) - padding;
    final top = math.min(math.min(p0.y, p1.y), math.min(p2.y, p3.y)) - padding;
    final right =
        math.max(math.max(p0.x, p1.x), math.max(p2.x, p3.x)) + padding;
    final bottom =
        math.max(math.max(p0.y, p1.y), math.max(p2.y, p3.y)) + padding;
    return ui.Rect.fromLTRB(left, top, right, bottom);
  }

  Future<ui.Image> _cropImage(
    ui.Image source, {
    required int left,
    required int top,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(
        left.toDouble(),
        top.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      ui.Rect.fromLTWH(0.0, 0.0, width.toDouble(), height.toDouble()),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }
}
