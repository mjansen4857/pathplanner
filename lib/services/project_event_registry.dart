/// Path-model-neutral registry of named commands used by the open project.
///
/// Event names are collected while paths and legacy autos are loaded. Keeping
/// the registry outside of either project page lets the legacy and Path2 editor
/// stacks share the command widgets without depending on one another.
class ProjectEventRegistry {
  ProjectEventRegistry._();

  static final Set<String> events = <String>{};

  static void clear() => events.clear();
}
