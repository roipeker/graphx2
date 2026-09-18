part of 'package:graphx/src/graphx_impl.dart';

bool _clipContains(GClip clip, double x, double y, GNode owner) {
  if (clip is GRectClip) {
    final rect = clip.rect;
    return x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom;
  }
  if (clip is GRoundRectClip) {
    return clip.rrect.contains(ui.Offset(x, y));
  }
  if (clip is GPathClip) {
    return clip.path.contains(ui.Offset(x, y));
  }
  if (clip is GInversePathClip) {
    final bounds = owner._ensureLocalBounds();
    if (bounds.isEmpty ||
        x < bounds.x1 ||
        x >= bounds.x2 ||
        y < bounds.y1 ||
        y >= bounds.y2) {
      return false;
    }

    if (clip._x1 != bounds.x1 ||
        clip._y1 != bounds.y1 ||
        clip._x2 != bounds.x2 ||
        clip._y2 != bounds.y2) {
      clip._x1 = bounds.x1;
      clip._y1 = bounds.y1;
      clip._x2 = bounds.x2;
      clip._y2 = bounds.y2;
      clip._path
        ..reset()
        ..fillType = ui.PathFillType.evenOdd
        ..addRect(ui.Rect.fromLTRB(clip._x1, clip._y1, clip._x2, clip._y2))
        ..addPath(clip._hole, ui.Offset.zero);
    }
    return clip._path.contains(ui.Offset(x, y));
  }
  return true;
}
