import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/coderunner/services/noop_telemetry.dart';
import 'package:pathplanner/coderunner/services/noop_update_checker.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/services/update_checker.dart';

void main() {
  test('noop telemetry reports disconnected and empty streams', () async {
    final PPLibTelemetry telemetry = CodeRunnerNoopTelemetry();

    expect(telemetry.isConnected, false);
    expect(telemetry.getServerAddress(), 'coderunner');
    expect(await telemetry.connectionStatusStream().first, false);
    expect(await telemetry.velocitiesStream().isEmpty, true);
    expect(await telemetry.currentPoseStream().isEmpty, true);
    expect(await telemetry.currentPathStream().isEmpty, true);
    expect(await telemetry.targetPoseStream().isEmpty, true);
  });

  test('noop update checker reports no updates', () async {
    final UpdateChecker checker = CodeRunnerNoopUpdateChecker();
    final fs = MemoryFileSystem();

    expect(await checker.isGuiUpdateAvailable('1.0.0'), false);
    expect(
        await checker.isPPLibUpdateAvailable(
            projectDir: fs.directory('/project'), fs: fs),
        false);
  });
}
