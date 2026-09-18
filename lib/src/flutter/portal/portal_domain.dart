part of 'package:graphx/graphx.dart';

final Expando<_GPortalDomain> _gPortalDomains = Expando<_GPortalDomain>(
  'graphx.portalDomain',
);

_GPortalDomain _portalDomainFor(GStage stage) {
  return _gPortalDomains[stage] ??= _GPortalDomain(stage);
}

_GPortalDomain? _maybePortalDomainFor(GStage stage) => _gPortalDomains[stage];

/// Reusable resolved Flutter presentation state for one portal.
final class _GPortalVisualState {
  final GMatrix2 world = GMatrix2();
  final Matrix4 transform = Matrix4.identity();

  double alpha = 1.0;
  bool visible = true;

  void resolve(GPortal<dynamic> portal) {
    _resolvePortalWorldTransform(portal, world);

    alpha = 1.0;
    visible = true;
    GNode? node = portal;
    while (node != null) {
      if (!node.active || !node.visible) visible = false;
      alpha *= node.alpha;
      node = node.parent;
    }

    final m = world;
    transform
      ..setIdentity()
      ..setEntry(0, 0, m.a)
      ..setEntry(1, 0, m.b)
      ..setEntry(0, 1, m.c)
      ..setEntry(1, 1, m.d)
      ..setEntry(0, 3, m.tx)
      ..setEntry(1, 3, m.ty);
  }
}

void _resolvePortalWorldTransform(GNode node, GMatrix2 out) {
  final parent = node.parent;
  if (parent == null) {
    out.identity();
  } else {
    _resolvePortalWorldTransform(parent, out);
  }
  if (node.hasLocalTransform) out.append(node.localMatrix);
}

final class _GPortalDomain extends ChangeNotifier {
  _GPortalDomain(this.stage);

  final GStage stage;
  final List<GPortal<dynamic>> _portals = <GPortal<dynamic>>[];
  final List<VoidCallback> _visualListeners = <VoidCallback>[];

  List<GPortal<dynamic>> get portals => _portals;

  void attach(GPortal<dynamic> portal) {
    if (_portals.contains(portal)) return;
    _portals.add(portal);
    notifyListeners();
  }

  void detach(GPortal<dynamic> portal) {
    if (!_portals.remove(portal)) return;
    if (!stage.isDisposed) notifyListeners();
  }

  void portalPlacementChanged(GPortal<dynamic> portal) {
    if (!_portals.contains(portal) || stage.isDisposed) return;
    notifyListeners();
  }

  void addVisualListener(VoidCallback listener) {
    if (_visualListeners.contains(listener)) return;
    _visualListeners.add(listener);
  }

  void removeVisualListener(VoidCallback listener) {
    _visualListeners.remove(listener);
  }

  /// Signals transform/alpha/visibility changes without rebuilding portal
  /// content. The host updates only its lightweight Flutter composition.
  void markVisualDirty() {
    if (_portals.isEmpty || stage.isDisposed) return;
    final listeners = _visualListeners;
    for (var i = 0; i < listeners.length; ++i) {
      listeners[i]();
    }
  }
}
