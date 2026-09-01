import 'package:file/file.dart';
import 'package:pathplanner/services/update_checker.dart';

/// Update checks are meaningless inside CodeRunner (the app version is
/// whatever the workspace image ships); always report "no update".
class CodeRunnerNoopUpdateChecker implements UpdateChecker {
  @override
  Future<bool> isGuiUpdateAvailable(String currentVersion) async => false;

  @override
  Future<bool> isPPLibUpdateAvailable(
          {required Directory projectDir, required FileSystem fs}) async =>
      false;
}
