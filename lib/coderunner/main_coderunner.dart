import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pathplanner/coderunner/app.dart';
import 'package:pathplanner/coderunner/config.dart';
import 'package:pathplanner/services/log.dart';

/// CodeRunner web entrypoint. Built with:
/// flutter build web -t lib/coderunner/main_coderunner.dart \
///   --base-href /pathplanner/ --no-web-resources-cdn
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Console-only logging; Log.init() writes to a local file via
  // path_provider, which has no web implementation.
  Log.logger = Logger(
    printer: SimplePrinter(),
    level: Level.info,
    filter: ProductionFilter(),
  );

  final config = CodeRunnerConfig.fromUri(Uri.base);
  if (config == null) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
              'Missing workspace. Open PathPlanner from the CodeRunner IDE.'),
        ),
      ),
    ));
    return;
  }

  final packageInfo = await PackageInfo.fromPlatform();

  runApp(CodeRunnerApp(
    config: config,
    appVersion: packageInfo.version,
  ));
}
