part of 'package:graphx/graphx.dart';

typedef GAssetLoader<T extends Object> = Future<T> Function();

/// Replaceable byte transport for URL-backed assets.
///
/// Implement this with Dio, a custom authenticated client, test fixtures, or
/// another transport when the default `package:http` loader is not appropriate.
/// The loader must return the complete response body or throw on failure.
typedef GAssetUrlLoader = Future<Uint8List> Function(Uri uri);

final class _GAssetEntry {
  _GAssetEntry(this.future);

  final Future<Object> future;
  Object? value;
}

/// Shared asset store/cache for GraphX runtimes and format packages.
final class GAssets implements Disposable {
  GAssets({GAssetUrlLoader? urlLoader}) : _urlLoader = urlLoader;

  final Map<Object, _GAssetEntry> _entries = <Object, _GAssetEntry>{};
  final GAssetUrlLoader? _urlLoader;

  http.Client? _networkClient;
  bool _disposed = false;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;

  bool has(Object key) => _entries.containsKey(key);

  T? get<T extends Object>(Object key) {
    final value = _entries[key]?.value;
    return value is T ? value : null;
  }

  Future<T> load<T extends Object>(
    Object key,
    GAssetLoader<T> loader, {
    bool cache = true,
  }) {
    _ensureAlive();

    if (cache) {
      final existing = _entries[key];
      if (existing != null) {
        final value = existing.value;
        if (value != null) {
          if (value is! T) {
            return Future<T>.error(
              StateError(
                'Asset key $key is cached as ${value.runtimeType}, not $T.',
              ),
            );
          }
          return Future<T>.value(value);
        }
        return existing.future.then((value) => value as T);
      }
    }

    late final Future<T> future;
    try {
      future = loader();
    } catch (error, stackTrace) {
      return Future<T>.error(error, stackTrace);
    }

    if (!cache) return future;

    final entry = _GAssetEntry(future);
    _entries[key] = entry;
    future.then<void>(
      (value) {
        if (identical(_entries[key], entry)) entry.value = value;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_entries[key], entry)) _entries.remove(key);
      },
    );
    return future;
  }

  void set<T extends Object>(Object key, T value) {
    _ensureAlive();
    final previous = _entries[key];
    final entry = _GAssetEntry(Future<T>.value(value))..value = value;
    _entries[key] = entry;
    if (previous != null) {
      previous.future.then<void>((old) {
        if (!identical(old, value)) _disposeValue(old);
      }, onError: (Object _, StackTrace _) {});
    }
  }

  Future<void> remove(Object key) async {
    final entry = _entries.remove(key);
    if (entry == null) return;
    try {
      _disposeValue(await entry.future);
    } catch (_) {}
  }

  Future<void> clear() async {
    final entries = _entries.values.toList(growable: false);
    _entries.clear();
    for (final entry in entries) {
      try {
        _disposeValue(await entry.future);
      } catch (_) {}
    }
  }

  Future<Uint8List> bytes(
    String assetPath, {
    AssetBundle? bundle,
    bool cache = true,
  }) {
    final resolved = bundle ?? rootBundle;
    return load<Uint8List>(
      ('bytes', assetPath, resolved),
      () => _readBundleBytes(resolved, assetPath),
      cache: cache,
    );
  }

  Future<Uint8List> bytesUrl(String url, {bool cache = true}) {
    final uri = Uri.parse(url);
    return load<Uint8List>(
      ('bytes-url', uri),
      () => _readNetworkBytes(uri),
      cache: cache,
    );
  }

  Future<Uint8List> bytesMemory(
    Uint8List bytes, {
    Object? key,
    bool cache = false,
  }) {
    if (!cache) return Future<Uint8List>.value(bytes);
    if (key == null) {
      throw ArgumentError('key is required when caching memory bytes.');
    }
    return load<Uint8List>(('bytes-memory', key), () async => bytes);
  }

  /// Loads image data, preserving animation when the codec has multiple frames.
  Future<GTextureData> image(
    String assetPath, {
    AssetBundle? bundle,
    bool cache = true,
    int? targetWidth,
    int? targetHeight,
  }) {
    final resolved = bundle ?? rootBundle;
    return load<GTextureData>(
      ('image', assetPath, resolved, targetWidth, targetHeight),
      () async => _decodeImageData(
        await _readBundleBytes(resolved, assetPath),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
      cache: cache,
    );
  }

  Future<GTextureData> imageUrl(
    String url, {
    bool cache = true,
    int? targetWidth,
    int? targetHeight,
  }) {
    final uri = Uri.parse(url);
    return load<GTextureData>(
      ('image-url', uri, targetWidth, targetHeight),
      () async => _decodeImageData(
        await _readNetworkBytes(uri),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
      cache: cache,
    );
  }

  Future<GTextureData> imageBytes(
    Uint8List bytes, {
    Object? key,
    bool cache = false,
    int? targetWidth,
    int? targetHeight,
  }) {
    Future<GTextureData> decode() => _decodeImageData(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    if (!cache) return decode();
    if (key == null) {
      throw ArgumentError('key is required when caching image bytes.');
    }
    return load<GTextureData>((
      'image-bytes',
      key,
      targetWidth,
      targetHeight,
    ), decode);
  }

  /// Loads a single texture. Animated formats resolve to their first frame.
  Future<GTexture> texture(
    String assetPath, {
    AssetBundle? bundle,
    bool cache = true,
    int? targetWidth,
    int? targetHeight,
  }) {
    final resolved = bundle ?? rootBundle;
    return load<GTexture>(
      ('texture', assetPath, resolved, targetWidth, targetHeight),
      () async => _decodeTexture(
        await _readBundleBytes(resolved, assetPath),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
      cache: cache,
    );
  }

  Future<GTexture> textureUrl(
    String url, {
    bool cache = true,
    int? targetWidth,
    int? targetHeight,
  }) {
    final uri = Uri.parse(url);
    return load<GTexture>(
      ('texture-url', uri, targetWidth, targetHeight),
      () async => _decodeTexture(
        await _readNetworkBytes(uri),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
      cache: cache,
    );
  }

  Future<GTexture> textureBytes(
    Uint8List bytes, {
    Object? key,
    bool cache = false,
    int? targetWidth,
    int? targetHeight,
  }) {
    Future<GTexture> decode() => _decodeTexture(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    if (!cache) return decode();
    if (key == null) {
      throw ArgumentError('key is required when caching texture bytes.');
    }
    return load<GTexture>((
      'texture-bytes',
      key,
      targetWidth,
      targetHeight,
    ), decode);
  }

  /// Loads all decoded frames as a general-purpose timed texture sequence.
  Future<GTextureSequence> textureSequence(
    String assetPath, {
    AssetBundle? bundle,
    bool cache = true,
    int? targetWidth,
    int? targetHeight,
  }) {
    final resolved = bundle ?? rootBundle;
    return load<GTextureSequence>(
      ('texture-sequence', assetPath, resolved, targetWidth, targetHeight),
      () async => _decodeTextureSequence(
        await _readBundleBytes(resolved, assetPath),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
      cache: cache,
    );
  }

  Future<GTextureSequence> textureSequenceUrl(
    String url, {
    bool cache = true,
    int? targetWidth,
    int? targetHeight,
  }) {
    final uri = Uri.parse(url);
    return load<GTextureSequence>(
      ('texture-sequence-url', uri, targetWidth, targetHeight),
      () async => _decodeTextureSequence(
        await _readNetworkBytes(uri),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
      cache: cache,
    );
  }

  Future<GTextureSequence> textureSequenceBytes(
    Uint8List bytes, {
    Object? key,
    bool cache = false,
    int? targetWidth,
    int? targetHeight,
  }) {
    Future<GTextureSequence> decode() => _decodeTextureSequence(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    if (!cache) return decode();
    if (key == null) {
      throw ArgumentError(
        'key is required when caching texture-sequence bytes.',
      );
    }
    return load<GTextureSequence>((
      'texture-sequence-bytes',
      key,
      targetWidth,
      targetHeight,
    ), decode);
  }

  /// Flutter integration escape hatch. It snapshots the currently resolved
  /// provider image into an independently-owned [GTexture].
  Future<GTexture> imageProvider(
    ImageProvider provider, {
    ImageConfiguration configuration = ImageConfiguration.empty,
    Object? key,
    bool cache = true,
  }) {
    final cacheKey = ('image-provider', key ?? provider, configuration);
    return load<GTexture>(cacheKey, () async {
      final stream = provider.resolve(configuration);
      final result = Completer<GTexture>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!result.isCompleted) {
            result.complete(GTexture.owned(info.image.clone()));
          }
          stream.removeListener(listener);
        },
        onError: (Object error, StackTrace? stackTrace) {
          if (!result.isCompleted) {
            result.completeError(error, stackTrace ?? StackTrace.current);
          }
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      return result.future;
    }, cache: cache);
  }

  static Future<Uint8List> _readBundleBytes(
    AssetBundle bundle,
    String key,
  ) async {
    final data = await bundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<Uint8List> _readNetworkBytes(Uri uri) async {
    final loader = _urlLoader;
    if (loader != null) return loader(uri);

    final response = await (_networkClient ??= http.Client()).get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HTTP ${response.statusCode} while loading $uri.');
    }
    return response.bodyBytes;
  }

  static Future<GTextureData> _decodeImageData(
    Uint8List bytes, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    try {
      if (codec.frameCount <= 1) {
        final frame = await codec.getNextFrame();
        return GTexture.owned(frame.image);
      }
      return await _decodeSequenceFromCodec(codec);
    } finally {
      codec.dispose();
    }
  }

  static Future<GTexture> _decodeTexture(
    Uint8List bytes, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    try {
      final frame = await codec.getNextFrame();
      return GTexture.owned(frame.image);
    } finally {
      codec.dispose();
    }
  }

  static Future<GTextureSequence> _decodeTextureSequence(
    Uint8List bytes, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    try {
      return await _decodeSequenceFromCodec(codec);
    } finally {
      codec.dispose();
    }
  }

  static Future<GTextureSequence> _decodeSequenceFromCodec(
    ui.Codec codec,
  ) async {
    final frames = <GTextureSequenceFrame>[];
    try {
      for (var i = 0; i < codec.frameCount; ++i) {
        final frame = await codec.getNextFrame();
        frames.add(
          GTextureSequenceFrame(GTexture.owned(frame.image), frame.duration),
        );
      }
      return GTextureSequence.owned(frames);
    } catch (_) {
      for (final frame in frames) {
        frame.texture.dispose();
      }
      rethrow;
    }
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('GAssets is disposed.');
  }

  static void _disposeValue(Object value) {
    if (value is Disposable && !value.isDisposed) value.dispose();
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _networkClient?.close();
    _networkClient = null;
    final entries = _entries.values.toList(growable: false);
    _entries.clear();
    for (final entry in entries) {
      entry.future.then<void>(
        _disposeValue,
        onError: (Object _, StackTrace _) {},
      );
    }
  }
}
