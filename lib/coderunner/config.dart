/// Deployment parameters passed by the CodeRunner shell via the iframe
/// URL: `/pathplanner/?ws=<workspace slug>`.
class CodeRunnerConfig {
  final String workspaceSlug;

  const CodeRunnerConfig({required this.workspaceSlug});

  String get apiBase => '/u/$workspaceSlug/api/deploy-files';

  // Mirrors ROUTE_SLUG_PATTERN in CodeRunner's @frc-coderunner/contracts.
  static final RegExp _slugPattern = RegExp(r'^[a-zA-Z0-9_-]{1,40}$');

  static CodeRunnerConfig? fromUri(Uri uri) {
    final slug = uri.queryParameters['ws'];
    if (slug == null || !_slugPattern.hasMatch(slug)) {
      return null;
    }
    return CodeRunnerConfig(workspaceSlug: slug);
  }
}
