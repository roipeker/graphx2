# GraphX 2

GraphX is a creative 2D scene framework for Flutter.

It gives you a direct way to draw, transform, animate, and interact with objects while still living naturally inside a Flutter app.

```dart
import 'dart:ui';

import 'package:graphx/graphx.dart';

GraphXView.scene((root) {
  final ball = root.addChild(GShape(name: 'ball'));

  ball.graphics.beginFill(const Color(0xffff4d4d));
  ball.graphics.drawCircle(0, 0, 40);

  ball.x = 200;
  ball.y = 160;

  ball.pointer.onTap.add((_) {
    ball.scaleX = ball.scaleY = 1.2;
  });
});
```

GraphX is built for interactive graphics, playful interfaces, visual tools, games, and the kinds of experiences that are easier to express as a scene than as a widget tree.

GraphX 2 is under active development. The core is working and tested while the public API, examples, and release experience are being refined.

## Use GraphX

GraphX 2 is not on pub.dev yet. Consume the public Git repository using Dart 3.9+ Git tag version solving:

```yaml
dependencies:
  graphx:
    git:
      url: https://github.com/roipeker/graphx2.git
      tag_pattern: v{{version}}
    version: ^2.0.0-dev.2
```

Then run:

```bash
flutter pub get
```

and import it normally:

```dart
import 'package:graphx/graphx.dart';
```

Using `tag_pattern` lets Pub select one compatible GraphX tag across the whole dependency graph. Avoid mixing literal `ref: main` and version tags for GraphX in normal project manifests because Pub treats different Git refs as different dependency sources.

For deliberate unreleased testing, keep the version-solved declaration above and use a root-level `dependency_overrides` entry pointing GraphX at `main` or a local checkout.

## Ecosystem

Official first-party extensions live in the separate [GraphX 2 Packages](https://github.com/roipeker/graphx2-packages) repository. Keeping the ecosystem separate lets the engine stay focused while packages such as paths, motion, atlas, particles, and arcade physics can evolve together.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

Code formatting and source style are documented in [STYLE.md](STYLE.md).

Examples, demos, and the GraphX site will live alongside the package so changes can be exercised quickly on web, iOS, Android, and desktop.

See [ROADMAP.md](ROADMAP.md) for what we are working on next.
