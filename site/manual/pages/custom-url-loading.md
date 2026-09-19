# Custom URL loading

The default URL loader is deliberately small: make a GET request, return the response bytes, fail on a bad status.

Applications often need more than that.

## Replace transport at the runtime boundary

`GRuntime` accepts a `GAssetUrlLoader`:

```dart
final runtime = GRuntime(
  urlLoader: loadPrivateAsset,
);
```

The function receives a parsed `Uri` and must return the complete response body as `Uint8List` or throw on failure:

```dart
typedef MyNetworkBytes = Future<Uint8List> Function(Uri uri);

final MyNetworkBytes appNetworkLoader = loadBytesForMyApp;
final runtime = GRuntime(
  urlLoader: appNetworkLoader,
);
```

`loadBytesForMyApp` in that example is deliberately application code, not a GraphX API. Its job is simply to satisfy the `Future<Uint8List> Function(Uri)` contract.

What happens inside that function is application policy. It can use authentication, signed requests, Dio, fixtures, an offline store, a proxy, or another transport entirely.

GraphX only asks for bytes.

## The cache sits above your transport

A custom loader does not need to reimplement the GraphX asset cache.

```dart
await stage.assets.textureUrl(url);
await stage.assets.textureUrl(url);
```

With normal caching enabled, the runtime store still deduplicates the request/decode. Your `urlLoader` is called only when the cache needs the source bytes.

If the loader throws, the failed cache entry is removed so another request can try again later.

## One transport policy can serve every GraphX view

Combine the custom runtime with `GRuntimeProvider`:

```dart
GRuntimeProvider(
  runtime: runtime,
  child: const AppBody(),
);
```

Every descendant `GraphXView` now uses that runtime's URL transport for:

```text
bytesUrl()
imageUrl()
textureUrl()
textureSequenceUrl()
```

That keeps authentication/network policy out of individual scene nodes.

A node asks for a texture. The runtime decides how remote bytes are obtained.

## Tests can replace the network completely

A custom loader is also a clean seam for deterministic tests:

```dart
final runtime = GRuntime(
  urlLoader: (uri) async {
    return fixtureBytes[uri]!;
  },
);
```

The scene can continue calling `textureUrl()` exactly as production code does while the test supplies controlled bytes without touching the network.

That is the main reason the URL loader lives at runtime level rather than as another parameter on every texture request: transport policy is shared infrastructure, not scene behavior.
