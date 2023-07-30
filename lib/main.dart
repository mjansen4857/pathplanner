import 'dart:async';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/services/update_checker.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/home_page.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Log.init();
      await windowManager.ensureInitialized();
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        Log.error('Flutter Error', details.exception, details.stack);
      };

      WindowOptions windowOptions = WindowOptions(
        size: const Size(1280, 720),
        minimumSize: const Size(640, 360),
        center: true,
        title: 'PathPlanner',
        titleBarStyle:
            Platform.isMacOS ? TitleBarStyle.normal : TitleBarStyle.hidden,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();

      PPLibTelemetry telemetry = PPLibTelemetry(
          serverBaseAddress: prefs.getString(PrefsKeys.pplibClientHost) ??
              Defaults.pplibClientHost);

      runApp(PathPlanner(
        appVersion: packageInfo.version,
        prefs: prefs,
        undoStack: ChangeStack(),
        telemetry: telemetry,
        updateChecker: UpdateChecker(),
      ));
    },
    (Object error, StackTrace stack) {
      Log.error('Dart Error', error, stack);
      exit(1);
    },
  );
}

class PathPlanner extends StatefulWidget {
  final String appVersion;
  final FileSystem fs;
  final SharedPreferences prefs;
  final ChangeStack undoStack;
  final PPLibTelemetry telemetry;
  final UpdateChecker updateChecker;

  const PathPlanner({
    required this.appVersion,
    required this.prefs,
    required this.undoStack,
    required this.telemetry,
    required this.updateChecker,
    this.fs = const LocalFileSystem(),
    super.key,
  });

  @override
  State<PathPlanner> createState() => _PathPlannerState();
}

class _PathPlannerState extends State<PathPlanner> {
  late Color _teamColor =
      Color(widget.prefs.getInt(PrefsKeys.teamColor) ?? Defaults.teamColor);
  final bool _sandboxed = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PathPlanner',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: _teamColor,
        useMaterial3: true,
      ),
      home: HomePage(
        appVersion: widget.appVersion,
        appStoreBuild: _sandboxed,
        prefs: widget.prefs,
        fs: widget.fs,
        undoStack: widget.undoStack,
        telemetry: widget.telemetry,
        updateChecker: widget.updateChecker,
        onTeamColorChanged: (Color color) {
          setState(() {
            _teamColor = color;
            widget.prefs.setInt(PrefsKeys.teamColor, _teamColor.value);
          });
        },
      ),
    );
  }
}
