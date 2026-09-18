// Copyright (c) 2026 GraphX by roipeker.

part of 'package:graphx/src/graphx_impl.dart';

abstract class GCursor {
  const GCursor();
  static const auto = GSystemCursor._(GSystemCursorType.auto);
  static const basic = GSystemCursor._(GSystemCursorType.basic);
  static const click = GSystemCursor._(GSystemCursorType.click);
  static const text = GSystemCursor._(GSystemCursorType.text);
  static const move = GSystemCursor._(GSystemCursorType.move);
  static const grab = GSystemCursor._(GSystemCursorType.grab);
  static const grabbing = GSystemCursor._(GSystemCursorType.grabbing);
  static const resizeH = GSystemCursor._(GSystemCursorType.resizeH);
  static const resizeV = GSystemCursor._(GSystemCursorType.resizeV);

  static const hidden = GHiddenCursor._();
}

enum GSystemCursorType {
  auto,
  basic,
  click,
  text,
  move,
  grab,
  grabbing,
  resizeH, // resizeLeftRight
  resizeV, // resizeUpDown
}

final class GSystemCursor extends GCursor {
  const GSystemCursor._(this.type);
  final GSystemCursorType type;
}

final class GHiddenCursor extends GCursor {
  const GHiddenCursor._();
}
