import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live app does not import the legacy path stack', () {
    final projectRoot = Directory.current.path;
    final libRoot = p.join(projectRoot, 'lib');
    final visited = <String>{};
    final pending = <String>[p.join(libRoot, 'pages', 'home_page.dart')];

    final forbiddenSuffixes = <String>[
      p.join('lib', 'pages', 'project', 'project_page.dart'),
      p.join('lib', 'pages', 'path_editor_page.dart'),
      p.join('lib', 'pages', 'auto_editor_page.dart'),
      p.join('lib', 'pages', 'choreo_path_editor_page.dart'),
      p.join('lib', 'widgets', 'editor', 'path_painter.dart'),
      p.join('lib', 'widgets', 'editor', 'split_path_editor.dart'),
      p.join('lib', 'widgets', 'editor', 'split_auto_editor.dart'),
      p.join('lib', 'widgets', 'editor', 'split_choreo_path_editor.dart'),
      p.join('lib', 'trajectory', 'trajectory.dart'),
      p.join('lib', 'trajectory', 'auto_simulator.dart'),
      p.join('lib', 'util', 'path_optimizer.dart'),
    ];

    while (pending.isNotEmpty) {
      final filePath = p.normalize(pending.removeLast());
      if (!visited.add(filePath)) {
        continue;
      }

      final relativePath = p.relative(filePath, from: projectRoot);
      expect(
        relativePath.startsWith(p.join('lib', 'path') + p.separator),
        isFalse,
        reason: 'The live import graph reached legacy path code: $relativePath',
      );
      expect(
        forbiddenSuffixes.any(relativePath.endsWith),
        isFalse,
        reason:
            'The live import graph reached legacy UI/simulation code: '
            '$relativePath',
      );
      expect(
        relativePath.toLowerCase().contains('choreo'),
        isFalse,
        reason: 'The live import graph reached Choreo code: $relativePath',
      );

      final source = File(filePath).readAsStringSync();
      final dependencies = RegExp(
        r'''^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]''',
        multiLine: true,
      ).allMatches(source);

      for (final match in dependencies) {
        final uri = match.group(1)!;
        String? importedPath;
        if (uri.startsWith('package:pathplanner/')) {
          importedPath = p.join(
            libRoot,
            uri.substring('package:pathplanner/'.length),
          );
        } else if (!uri.contains(':')) {
          importedPath = p.normalize(p.join(p.dirname(filePath), uri));
        }

        if (importedPath != null && File(importedPath).existsSync()) {
          pending.add(importedPath);
        }
      }
    }
  });
}
