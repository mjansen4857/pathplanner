import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/coderunner/platform/platform_shim.dart';
import 'package:pathplanner/coderunner/web_mode.dart';

void main() {
  test('web mode defaults to disabled', () {
    expect(CodeRunnerWebMode.enabled, false);
  });

  test('platform shim matches dart:io on the VM', () {
    // Tests run on the Dart VM, so the io implementation is active and
    // exactly one desktop platform (or none, on CI containers) is true.
    final flags = [
      PlatformShim.isMacOS,
      PlatformShim.isWindows,
      PlatformShim.isLinux,
    ];
    expect(flags.where((f) => f).length, lessThanOrEqualTo(1));
  });
}
