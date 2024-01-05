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
  static const String seen2024ResetPopup = 'seen2024ResetPopup';
  static const String holonomicMode = 'holonomicMode';
  static const String ntServerAddress = 'pplibClientHost';
  static const String pathSortOption = 'pathSortOption';
  static const String autoSortOption = 'autoSortOption';
  static const String pathsCompactView = 'pathsCompactView';
  static const String autosCompactView = 'pathsCompactView';
  static const String hotReloadEnabled = 'hotReloadEnabled';
  static const String pathFolders = 'pathFolders';
  static const String autoFolders = 'autoFolders';
  static const String snapToGuidelines = 'snapToGuidelines';
  static const String hidePathsOnHover = 'hidePathsOnHover';
  static const String defaultMaxVel = 'defaultMaxVel';
  static const String defaultMaxAccel = 'defaultMaxAccel';
  static const String defaultMaxAngVel = 'defaultMaxAngVel';
  static const String defaultMaxAngAccel = 'defaultMaxAngAccel';
  static const String maxModuleSpeed = 'maxModuleSpeed';
}

class Defaults {
  static const int teamColor = 0xFF3F51B5;
  static const double robotWidth = 0.9;
  static const double robotLength = 0.9;
  static const bool holonomicMode = true;
  static const double projectLeftWeight = 0.5;
  static const double editorTreeWeight = 0.5;
  static const String ntServerAddress = 'localhost';
  static const bool treeOnRight = true;
  static const String pathSortOption = 'recent';
  static const String autoSortOption = 'recent';
  static const bool pathsCompactView = false;
  static const bool autosCompactView = false;
  static const bool hotReloadEnabled = false;
  static List<String> pathFolders =
      []; // Can't be const or user wont be able to add new folders
  static List<String> autoFolders =
      []; // Can't be const or user wont be able to add new folders
  static const bool snapToGuidelines = true;
  static const bool hidePathsOnHover = true;
  static const double defaultMaxVel = 3.0;
  static const double defaultMaxAccel = 3.0;
  static const double defaultMaxAngVel = 540.0;
  static const double defaultMaxAngAccel = 720.0;
  static const double maxModuleSpeed = 4.5;
}
