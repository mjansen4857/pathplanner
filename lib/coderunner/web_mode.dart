/// Global switch for the CodeRunner web build. Set to true by the
/// CodeRunner entrypoint (lib/coderunner/main_coderunner.dart) before the
/// app starts; never set on desktop. Guard edits in upstream files check
/// this instead of kIsWeb so widget tests can enable it on the VM.
class CodeRunnerWebMode {
  CodeRunnerWebMode._();

  static bool enabled = false;
}
