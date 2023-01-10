import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pathplanner/services/log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Log.init();

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
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

      runApp(PathPlanner(
        appVersion: packageInfo.version,
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

  const PathPlanner({required this.appVersion, super.key});

  @override
  State<PathPlanner> createState() => _PathPlannerState();
}

class _PathPlannerState extends State<PathPlanner> {
  SharedPreferences? _prefs;
  late Color _teamColor;
  final bool _sandboxed = false;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _prefs = prefs;
        _teamColor = Color(_prefs!.getInt('teamColor') ?? Colors.indigo.value);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_prefs == null) return Container();

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
        prefs: _prefs!,
        onTeamColorChanged: (Color color) {
          setState(() {
            _teamColor = color;
            _prefs!.setInt('teamColor', _teamColor.value);
          });
        },
      ),
    );
  }
}
