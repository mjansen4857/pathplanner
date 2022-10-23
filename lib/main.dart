import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
// ignore: implementation_imports
import 'package:logger/src/outputs/file_output.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Directory logPath = await getApplicationSupportDirectory();

  Logger logger = Logger(
    printer: PrettyPrinter(
      colors: false,
      printTime: true,
    ),
    output: MultiOutput([
      ConsoleOutput(),
      FileOutput(
        file: File(join(logPath.path, 'log.txt')),
      ),
    ]),
    filter: ProductionFilter(),
  );

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await windowManager.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        logger.e('Flutter Error', details.exception, details.stack);
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

      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      runApp(PathPlanner(
        logger: logger,
        appVersion: packageInfo.version,
        appStoreBuild: packageInfo.installerStore !=
            null, // This will only be true if installed from apple app store
      ));
    },
    (Object error, StackTrace stack) {
      logger.e('Dart Error', error, stack);
      exit(1);
    },
  );
}

class PathPlanner extends StatefulWidget {
  final FieldImage defaultField = FieldImage.official(OfficialField.rapidReact);
  final String appVersion;
  final bool appStoreBuild;
  final Logger logger;

  PathPlanner(
      {required this.logger,
      required this.appVersion,
      required this.appStoreBuild,
      super.key});

  @override
  State<PathPlanner> createState() => _PathPlannerState();
}

class _PathPlannerState extends State<PathPlanner> {
  SharedPreferences? _prefs;
  late Color _teamColor;

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
        defaultFieldImage: widget.defaultField,
        appVersion: widget.appVersion,
        appStoreBuild: widget.appStoreBuild,
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
