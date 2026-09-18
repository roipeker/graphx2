# GraphX 2

GraphX is a creative 2D scene framework for Flutter.

It gives you a direct way to draw, transform, animate, and interact with objects while still living naturally inside a Flutter app.

```dart
import 'dart:ui';

import 'package:graphx/graphx.dart';

GraphXView.scene((root) {
  final ball = root.addChild(GShape(name: 'ball'));

  ball.graphics
    ..beginFill(const Color(0xffff4d4d))
    ..drawCircle(0, 0, 40);

  ball
    ..x = 200
    ..y = 160;

  ball.pointer.onTap.add((_) {
    ball.scaleX = ball.scaleY = 1.2;
  });
});
```

GraphX is built for interactive graphics, playful interfaces, visual tools, games, and the kinds of experiences that are easier to express as a scene than as a widget tree.

GraphX 2 is under active development. The core is working and tested while the public API, examples, and release experience are being refined.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

Code formatting and source style are documented in [STYLE.md](STYLE.md).

Examples, demos, and the GraphX site will live alongside the package so changes can be exercised quickly on web, iOS, Android, and desktop.

See [ROADMAP.md](ROADMAP.md) for what we are working on next.
