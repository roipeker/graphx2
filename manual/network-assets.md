# Network assets

A remote image eventually becomes the same thing as a local one: bytes, decoded by Flutter, wrapped in a GraphX texture.

The URL helpers handle that path directly.

## Load a texture from a URL

```dart
final texture = await stage.assets.textureUrl(
  'https://example.com/player.png',
);
```

Other URL variants mirror the bundle/memory APIs:

```dart
await stage.assets.bytesUrl(url);
await stage.assets.imageUrl(url);
await stage.assets.textureSequenceUrl(url);
```

`imageUrl()` preserves animation when the codec reports multiple frames. `textureUrl()` asks for one texture and uses the first decoded frame.

## URL loads are cached by default

The URL and decode options become part of the cache identity:

```dart
await stage.assets.textureUrl(
  url,
  targetWidth: 128,
);
```

A later request with the same URL/options shares the cached result. A different target size gets a different decoded texture.

Failed cached loads are removed, so a later request can retry.

## The default transport is intentionally boring

If you do not provide a custom URL loader, GraphX lazily uses a `package:http` client and performs a normal GET request.

Non-2xx responses fail the load. The client is closed when the asset store is disposed.

That default is enough for public images and simple APIs. Authentication, custom headers, signed URLs, offline fixtures, retries, or a different networking stack belong in [Custom URL loading](#custom-url-loading).

## Web still obeys browser CORS

On Flutter web, GraphX is still running inside the browser's networking/security model.

If a remote server does not allow your origin to read the response, GraphX cannot bypass that with a texture API. The server must provide the appropriate CORS headers or the request must go through infrastructure that does.

That is a transport/browser rule, not a GraphX rendering limitation.

## Async ownership still matters

Network latency makes the lifecycle rule from [Flutter assets](#flutter-assets) even more relevant:

```dart
final texture = await stage.assets.textureUrl(url);
if (isDisposed || !isAttached) return;

addChild(GImage(texture));
```

The cache may keep the texture for other consumers even when this particular node disappeared before the request completed.

Resource lifetime belongs to the runtime; scene mutation still belongs to the node lifecycle.
