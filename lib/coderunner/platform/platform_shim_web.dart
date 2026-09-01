/// Web implementation: the CodeRunner build is never a desktop platform.
class PlatformShim {
  PlatformShim._();

  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
}
