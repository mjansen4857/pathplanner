/// Project-wide names used by condition transitions in Path 2 graphs.
class ProjectConditionRegistry {
  ProjectConditionRegistry._();

  static final Set<String> conditions = <String>{};

  static void clear() => conditions.clear();

  static void register(String? name) {
    if (name != null && name.trim().isNotEmpty) {
      conditions.add(name);
    }
  }

  static void rebuild(Iterable<String?> names) {
    clear();
    for (final name in names) {
      register(name);
    }
  }
}
