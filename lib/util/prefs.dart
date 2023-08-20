class PrefsKeys {
  static const String editorTreeWeight = 'editorTreeWeight';
  static const String projectLeftWeight = 'projectLeftWeight';
  static const String treeOnRight = 'treeOnRight';
  static const String robotWidth = 'robotWidth';
  static const String robotLength = 'robotLength';
  static const String teamColor = 'teamColor';
  static const String currentProjectDir = 'currentProjectDir';
  static const String macOSBookmark = 'macOSBookmark';
  static const String fieldImage = 'fieldImage';
  static const String seen2023Warning = 'seen2023Warning';
  static const String holonomicMode = 'holonomicMode';
  static const String pplibClientHost = 'pplibClientHost';
  static const String pathSortOption = 'pathSortOption';
  static const String autoSortOption = 'autoSortOption';
  static const String pathsCompactView = 'pathsCompactView';
  static const String autosCompactView = 'pathsCompactView';
  static const String hotReloadEnabled = 'hotReloadEnabled';
  static const String pathFolders = 'pathFolders';
  static const String autoFolders = 'autoFolders';
  static const String displaySimPath = 'displaySimPath';
  static const String snapToGuidelines = 'snapToGuidelines';
}

class Defaults {
  static const int teamColor = 0xFF3F51B5;
  static const double robotWidth = 0.9;
  static const double robotLength = 0.9;
  static const bool holonomicMode = true;
  static const double projectLeftWeight = 0.5;
  static const double editorTreeWeight = 0.5;
  static const String pplibClientHost = 'localhost';
  static const bool treeOnRight = true;
  static const String pathSortOption = 'nameAsc';
  static const String autoSortOption = 'nameAsc';
  static const bool pathsCompactView = false;
  static const bool autosCompactView = false;
  static const bool hotReloadEnabled = false;
  static List<String> pathFolders =
      []; // Can't be const or user wont be able to add new folders
  static List<String> autoFolders =
      []; // Can't be const or user wont be able to add new folders
  static const bool displaySimPath = false;
  static const bool snapToGuidelines = true;
}
