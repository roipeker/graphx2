part of 'package:graphx/graphx.dart';

/// Flutter/dart:ui interop for GraphX geometry primitives.
extension GPointFlutterGeometry on GPoint {
  ui.Offset get offset => ui.Offset(x, y);

  void setFromOffset(ui.Offset value) {
    x = value.dx;
    y = value.dy;
  }
}

extension OffsetGraphXGeometry on ui.Offset {
  GPoint get gpoint => GPoint(dx, dy);

  void copyInto(GPoint out) {
    out.x = dx;
    out.y = dy;
  }
}

extension GSizeFlutterGeometry on GSize {
  ui.Size get size => ui.Size(width, height);

  void setFromSize(ui.Size value) {
    width = value.width;
    height = value.height;
  }
}

extension SizeGraphXGeometry on ui.Size {
  GSize get gsize => GSize(width, height);

  void copyInto(GSize out) {
    out.width = width;
    out.height = height;
  }
}

extension GRectFlutterGeometry on GRect {
  ui.Rect get rect => ui.Rect.fromLTWH(x, y, w, h);

  void setFromRect(ui.Rect value) {
    x = value.left;
    y = value.top;
    w = value.width;
    h = value.height;
  }
}

extension RectGraphXGeometry on ui.Rect {
  GRect get grect => GRect(left, top, width, height);

  void copyInto(GRect out) {
    out.x = left;
    out.y = top;
    out.w = width;
    out.h = height;
  }
}

extension GBoundsFlutterGeometry on GBounds {
  ui.Rect get rect => isEmpty ? ui.Rect.zero : ui.Rect.fromLTRB(x1, y1, x2, y2);

  void setFromRect(ui.Rect value) {
    set(value.left, value.top, value.right, value.bottom);
  }
}

extension RectGraphXBoundsGeometry on ui.Rect {
  GBounds get gbounds => GBounds(left, top, right, bottom);

  void copyIntoBounds(GBounds out) {
    out.set(left, top, right, bottom);
  }
}
