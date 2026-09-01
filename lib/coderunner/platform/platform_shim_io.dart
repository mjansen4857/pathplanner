import 'dart:io' as io;

/// dart:io-backed implementation, active on desktop and in flutter test.
class PlatformShim {
  PlatformShim._();

  static bool get isMacOS => io.Platform.isMacOS;
  static bool get isWindows => io.Platform.isWindows;
  static bool get isLinux => io.Platform.isLinux;
}
