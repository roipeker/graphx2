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

## IDE setup

Open the repository root in the IDE so Dart can pick up `analysis_options.yaml` and `.editorconfig`. Do not duplicate the 100-column or trailing-comma rules in personal IDE settings.

### VS Code

Use the official Dart extension and, if you like format-on-save, let the Dart formatter handle Dart files:

```json
"[dart]": {
  "editor.defaultFormatter": "Dart-Code.dart-code",
  "editor.formatOnSave": true
}
```

### IntelliJ / Android Studio

Enable the Dart/Flutter plugin and use the project's Flutter SDK. Use the Dart formatter for **Reformat Code**, and optionally enable reformat-on-save. The repository settings remain the source of truth; no separate IntelliJ line-width profile is needed.

Formatting is a local development convention. There is no CI check and formatting does not block commits or pushes.
