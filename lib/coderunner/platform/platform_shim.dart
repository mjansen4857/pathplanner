// Replacement for dart:io Platform checks that is safe on web.
// Defaults to the web stub; the io implementation is selected wherever
// dart:io actually works (desktop, flutter test VM).
export 'package:pathplanner/coderunner/platform/platform_shim_web.dart'
    if (dart.library.io) 'package:pathplanner/coderunner/platform/platform_shim_io.dart';
