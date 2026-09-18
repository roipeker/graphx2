# Code style

GraphX uses the standard Dart formatter. Formatting should look the same in VS Code, IntelliJ, and the command line.

- Line width: 100 characters.
- Trailing commas are preserved. Add one when you intentionally want a call, collection, or declaration to stay expanded across lines.
- Do not use comments or manual spacing to fight the formatter.
- Use `// dart format off` / `// dart format on` only when the layout itself carries meaning, such as matrices, lookup tables, or geometry fixtures.
- Keep format-disabled regions small.
- Dart source files start with the GraphX copyright line (`// Copyright (c) 2026 GraphX by roipeker.`).

Before committing code, normal formatting is simply:

```bash
dart format lib test benchmark example
```

The repository does not reject commits or pushes based on formatting. The shared formatter configuration is the standard.
