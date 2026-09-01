import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/coderunner/api/deploy_files_client.dart';
import 'package:pathplanner/coderunner/app.dart';
import 'package:pathplanner/coderunner/config.dart';
import 'package:pathplanner/coderunner/web_mode.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeClient extends DeployFilesClient {
  final List<SnapshotFile> snapshot;
  final bool failSnapshot;

  FakeClient({this.snapshot = const [], this.failSnapshot = false})
      : super(baseUrl: '/unused');

  @override
  Future<List<SnapshotFile>> fetchSnapshot() async {
    if (failSnapshot) {
      throw const DeployFilesException(statusCode: 503, message: 'down');
    }
    return snapshot;
  }

  @override
  Future<void> putFile(String path, String content) async {}

  @override
  Future<void> deleteFile(String path) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      // Suppress the one-time field-reset popup so the test sees the
      // project page directly.
      PrefsKeys.seen2026ResetPopup: true,
    });
  });

  tearDown(() {
    CodeRunnerWebMode.enabled = false;
  });

  testWidgets('boots into the project page from an empty snapshot',
      (tester) async {
    await tester.pumpWidget(CodeRunnerApp(
      config: const CodeRunnerConfig(workspaceSlug: 'tester'),
      appVersion: '0.0.0',
      client: FakeClient(),
    ));

    // Hydration future + HomePage init animations.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(CodeRunnerWebMode.enabled, true);
    expect(find.byType(ProjectPage), findsOneWidget);
  });

  testWidgets('shows a retryable error when hydration fails', (tester) async {
    await tester.pumpWidget(CodeRunnerApp(
      config: const CodeRunnerConfig(workspaceSlug: 'tester'),
      appVersion: '0.0.0',
      client: FakeClient(failSnapshot: true),
    ));

    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.textContaining('Failed to load'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });
}
