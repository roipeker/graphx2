part of 'package:graphx/graphx.dart';

/// Format-agnostic collection of named texture views.
///
/// Atlas decoders live outside GraphX core. They populate this object with
/// borrowed [GTexture] views that already contain region, trim, and rotation
/// metadata. The atlas supports multiple backing pages and can derive simple
/// timed [GTextureSequence] values without introducing packer-specific
/// conventions.
final class GTextureAtlas implements Disposable {
  GTextureAtlas({
    Iterable<GTexture> pages = const <GTexture>[],
    Map<String, GTexture> textures = const <String, GTexture>{},
    this.ownsPages = false,
  }) : pages = List<GTexture>.unmodifiable(pages),
       _textures = Map<String, GTexture>.unmodifiable(textures);

  /// Backing page textures used by this atlas.
  ///
  /// Entries may reference any page. Multi-page atlases therefore use the same
  /// lookup API as single-page atlases.
  final List<GTexture> pages;

  /// Whether disposing this atlas also disposes its backing [pages].
  final bool ownsPages;

  final Map<String, GTexture> _textures;

  int get length => _textures.length;
  bool get isEmpty => _textures.isEmpty;
  bool get isNotEmpty => _textures.isNotEmpty;

  Iterable<String> get names => _textures.keys;
  Iterable<GTexture> get textures => _textures.values;

  bool contains(String name) => _textures.containsKey(name);

  /// Returns the named texture or `null` when it does not exist.
  GTexture? find(String name) => _textures[name];

  /// Returns the named texture and throws when it does not exist.
  GTexture texture(String name) => this[name];

  GTexture operator [](String name) {
    final texture = _textures[name];
    if (texture == null) {
      throw StateError('Texture "$name" was not found in this atlas.');
    }
    return texture;
  }

  /// Builds a borrowed texture sequence from explicitly ordered atlas names.
  ///
  /// Naming conventions such as `run_0001`, TexturePacker tags, or Starling
  /// XML prefixes belong to decoder/helper packages rather than this primitive.
  GTextureSequence sequence(
    Iterable<String> names, {
    required Duration frameDuration,
  }) {
    if (frameDuration <= Duration.zero) {
      throw ArgumentError.value(
        frameDuration,
        'frameDuration',
        'must be greater than zero',
      );
    }

    final frames = <GTextureSequenceFrame>[];
    for (final name in names) {
      frames.add(GTextureSequenceFrame(this[name], frameDuration));
    }

    if (frames.isEmpty) {
      throw ArgumentError.value(names, 'names', 'must not be empty');
    }

    return GTextureSequence(frames);
  }

  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Named entries are borrowed texture views. Their lifetime follows the
    // backing page/image, not the atlas wrapper itself.
    if (!ownsPages) return;
    for (final page in pages) {
      page.dispose();
    }
  }
}
