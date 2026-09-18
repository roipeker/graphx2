part of 'package:graphx/graphx.dart';

/// Sparse defaults for [GIcon] descendants of a [GDefaults] scope.
@immutable
final class GIconStyle {
  const GIconStyle({this.color, this.size});

  final Color? color;
  final double? size;

  GIconStyle merge(GIconStyle? other) {
    if (other == null) return this;
    return GIconStyle(color: other.color ?? color, size: other.size ?? size);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GIconStyle && other.color == color && other.size == size;

  @override
  int get hashCode => Object.hash(color, size);
}

/// Transparent scene-tree scope for sparse visual defaults.
///
/// Defaults cascade through nested scopes. A visual keeps any properties it
/// specifies locally and inherits the rest from its nearest ancestors.
///
/// Extension packages may subclass this node to carry their own retained
/// defaults alongside GraphX text/icon defaults. Core resolution deliberately
/// recognizes subclasses as normal [GDefaults] scopes, allowing packages such
/// as a UI layer to share one inheritance boundary instead of creating a
/// parallel theme tree.
class GDefaults extends GNode {
  GDefaults({
    GTextStyle? textStyle,
    GIconStyle? iconStyle,
    TextScaler? textScaler,
  }) : _textStyle = textStyle,
       _iconStyle = iconStyle,
       _textScaler = textScaler;

  GTextStyle? _textStyle;
  GIconStyle? _iconStyle;
  TextScaler? _textScaler;

  GTextStyle? get textStyle => _textStyle;
  set textStyle(GTextStyle? value) {
    if (_textStyle == value) return;
    _textStyle = value;
    _invalidateText();
  }

  GIconStyle? get iconStyle => _iconStyle;
  set iconStyle(GIconStyle? value) {
    if (_iconStyle == value) return;
    _iconStyle = value;
    _invalidateIcons();
  }

  /// Optional text scaling inherited by descendant [GText] nodes.
  /// Defaults to [TextScaler.noScaling] when no scope provides one.
  TextScaler? get textScaler => _textScaler;
  set textScaler(TextScaler? value) {
    if (_textScaler == value) return;
    _textScaler = value;
    _invalidateTextScale();
  }

  /// Invalidates package-specific defaults consumers below this scope.
  ///
  /// Subclasses can call this after changing their own retained defaults.
  /// Descendants receive [GNode.inheritedDefaultsChanged] without forcing core
  /// text or icon caches to rebuild when those core defaults did not change.
  @protected
  void invalidateDescendantDefaults() {
    _visitDescendants((node) => node.inheritedDefaultsChanged());
  }

  void _invalidateText() {
    _visitDescendants((node) {
      if (node is GText) node._defaultsChanged();
    });
  }

  void _invalidateTextScale() {
    _visitDescendants((node) {
      if (node is GText) node._textScalerChanged();
    });
  }

  void _invalidateIcons() {
    _visitDescendants((node) {
      if (node is GIcon) node._defaultsChanged();
    });
  }

  void _visitDescendants(void Function(GNode node) visitor) {
    final children = _children;
    if (children == null) return;
    for (var i = 0; i < children.length; ++i) {
      final child = children[i];
      visitor(child);
      if (child is GDefaults) {
        child._visitDescendants(visitor);
      } else {
        _visitNodeDescendants(child, visitor);
      }
    }
  }
}

void _visitNodeDescendants(GNode node, void Function(GNode node) visitor) {
  final children = node._children;
  if (children == null) return;
  for (var i = 0; i < children.length; ++i) {
    final child = children[i];
    visitor(child);
    _visitNodeDescendants(child, visitor);
  }
}

void _defaultsReparented(GNode subtree, GNode? oldParent, GNode? newParent) {
  if (!_hasDefaults(oldParent) && !_hasDefaults(newParent)) return;
  _invalidateDefaultConsumers(subtree);
}

bool _hasDefaults(GNode? node) {
  while (node != null) {
    if (node is GDefaults) return true;
    node = node.parent;
  }
  return false;
}

void _invalidateDefaultConsumers(GNode node) {
  node.inheritedDefaultsChanged();
  if (node is GText) {
    node._defaultsChanged();
    node._textScalerChanged();
  }
  if (node is GIcon) node._defaultsChanged();
  final children = node._children;
  if (children == null) return;
  for (var i = 0; i < children.length; ++i) {
    _invalidateDefaultConsumers(children[i]);
  }
}

GTextStyle _resolveTextStyle(GNode node, GTextStyle local) {
  var resolved = local;
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    if (parent is! GDefaults) continue;
    final style = parent._textStyle;
    if (style != null) resolved = style.merge(resolved);
  }
  return GText.defaultStyle.merge(resolved);
}

TextScaler _resolveTextScaler(GNode node) {
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    if (parent is! GDefaults) continue;
    final scaler = parent._textScaler;
    if (scaler != null) return scaler;
  }
  return TextScaler.noScaling;
}

GIconStyle _resolveIconStyle(GNode node, {double? size, Color? color}) {
  var resolved = GIconStyle(size: size, color: color);
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    if (parent is! GDefaults) continue;
    final style = parent._iconStyle;
    if (style != null) resolved = style.merge(resolved);
  }
  return GIcon.defaultStyle.merge(resolved);
}
