// Copyright (c) 2026 GraphX by roipeker.

import 'dart:convert';
import 'dart:io';

final _linkPattern = RegExp(r'^- \[([^\]]+)\]\(([^)]+\.md)\)$');
final _itemPattern = RegExp(r'^- (.+)$');

void main() {
  final repo = Directory.current;
  final manual = Directory('${repo.path}/manual');
  final theme = Directory('${repo.path}/tool/manual_theme');
  final site = Directory('${repo.path}/site');
  final output = Directory('${site.path}/manual');
  final pages = Directory('${output.path}/pages');

  if (!File('${manual.path}/README.md').existsSync()) {
    stderr.writeln('Run this command from the GraphX repository root.');
    exitCode = 2;
    return;
  }

  if (output.existsSync()) output.deleteSync(recursive: true);
  pages.createSync(recursive: true);

  final toc = _readToc(manual);
  final existingPages =
      manual
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.md') && !file.path.endsWith('/README.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final version = _buildVersion(manual, theme, existingPages);

  for (final page in existingPages) {
    page.copySync('${pages.path}/${_basename(page.path)}');
  }

  for (final name in ['book.css', 'book.js']) {
    File('${theme.path}/$name').copySync('${output.path}/$name');
  }

  final manualAssets = Directory('${manual.path}/assets');
  if (manualAssets.existsSync()) {
    _copyDirectory(manualAssets, Directory('${output.path}/assets'));
  }

  final nav = StringBuffer();
  var chapter = 0;
  for (final group in toc) {
    nav.writeln('<p class="nav-group">${_escape(group.title)}</p>');
    for (final item in group.items) {
      final file = item.file ?? '${_slug(item.title)}.md';
      final exists = File('${manual.path}/$file').existsSync();
      if (exists) {
        chapter++;
        nav.writeln(
          '<a class="nav-link${chapter == 1 ? ' active' : ''}" '
          'href="#${_slug(item.title)}" data-page="pages/${_escapeAttribute(file)}?v=$version" '
          'data-chapter="$chapter" data-group="${_escapeAttribute(group.title)}">'
          '${_escape(item.title)}</a>',
        );
      } else {
        nav.writeln('<span class="nav-link pending">${_escape(item.title)}</span>');
      }
    }
  }

  final template = File('${theme.path}/index.html').readAsStringSync();
  File('${output.path}/index.html').writeAsStringSync(
    template
        .replaceFirst('{{NAV}}', nav.toString())
        .replaceFirst('{{FIRST_PAGE}}', _firstPage(toc, manual, version))
        .replaceAll('{{ASSET_VERSION}}', version),
  );

  File('${site.path}/index.html').writeAsStringSync('''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <title>GraphX 2</title>
  <style>
    html,body{height:100%;margin:0}body{display:grid;place-items:center;background:#111;color:#f5f5f2;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}a{color:inherit;text-underline-offset:4px}.wrap{text-align:center}.mark{font:700 34px/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:-.08em}.sub{color:#888;margin:12px 0 28px}
  </style>
</head>
<body><div class="wrap"><div class="mark">GX²</div><div class="sub">GraphX 2 · work in progress</div><a href="manual/">Read the manual →</a></div></body>
</html>
''');

  stdout.writeln(
    'Built GraphX manual: ${existingPages.length} page(s), $chapter published chapter(s).',
  );
}

String _buildVersion(Directory manual, Directory theme, List<File> pages) {
  var hash = 0x811c9dc5;

  void add(String value) {
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
  }

  add(File('${manual.path}/README.md').readAsStringSync());
  for (final page in pages) {
    add(_basename(page.path));
    add(page.readAsStringSync());
  }
  for (final name in ['index.html', 'book.css', 'book.js']) {
    add(File('${theme.path}/$name').readAsStringSync());
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final name = _basename(entity.path);
    if (entity is Directory) {
      _copyDirectory(entity, Directory('${destination.path}/$name'));
    } else if (entity is File) {
      entity.copySync('${destination.path}/$name');
    }
  }
}

String _firstPage(List<_Group> groups, Directory manual, String version) {
  for (final group in groups) {
    for (final item in group.items) {
      final file = item.file ?? '${_slug(item.title)}.md';
      if (File('${manual.path}/$file').existsSync()) {
        return 'pages/${_escapeAttribute(file)}?v=$version';
      }
    }
  }
  throw StateError('The manual has no published chapters.');
}

List<_Group> _readToc(Directory manual) {
  final groups = <_Group>[];
  _Group? current;
  for (final raw in File('${manual.path}/README.md').readAsLinesSync()) {
    final line = raw.trim();
    if (line.startsWith('## ')) {
      current = _Group(line.substring(3));
      groups.add(current);
      continue;
    }
    if (current == null) continue;
    final link = _linkPattern.firstMatch(line);
    if (link != null) {
      current.items.add(_Item(link.group(1)!, link.group(2)));
      continue;
    }
    final item = _itemPattern.firstMatch(line);
    if (item != null) current.items.add(_Item(item.group(1)!));
  }
  return groups;
}

String _basename(String path) => path.split(Platform.pathSeparator).last;

String _slug(String value) => value
    .toLowerCase()
    .replaceAll('&', ' and ')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _escape(String value) => const HtmlEscape(HtmlEscapeMode.element).convert(value);
String _escapeAttribute(String value) => const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

final class _Group {
  _Group(this.title);
  final String title;
  final List<_Item> items = [];
}

final class _Item {
  _Item(this.title, [this.file]);
  final String title;
  final String? file;
}
