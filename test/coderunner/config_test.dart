import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/coderunner/config.dart';

void main() {
  test('parses the workspace slug from the ws query parameter', () {
    final config = CodeRunnerConfig.fromUri(
        Uri.parse('https://example.com/pathplanner/?ws=alice-1'));

    expect(config, isNotNull);
    expect(config!.workspaceSlug, 'alice-1');
    expect(config.apiBase, '/u/alice-1/api/deploy-files');
  });

  test('rejects a missing slug', () {
    expect(
        CodeRunnerConfig.fromUri(Uri.parse('https://example.com/pathplanner/')),
        isNull);
  });

  test('rejects an invalid slug', () {
    expect(
        CodeRunnerConfig.fromUri(
            Uri.parse('https://example.com/pathplanner/?ws=../etc')),
        isNull);
    expect(
        CodeRunnerConfig.fromUri(
            Uri.parse('https://example.com/pathplanner/?ws=has space')),
        isNull);
  });
}
