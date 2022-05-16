import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
// ignore: implementation_imports
import 'package:logger/src/outputs/file_output.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Directory logPath = await getApplicationSupportDirectory();
  File logFile = File(join(logPath.path, 'log.txt'));
  Logger logger = Logger(
    printer: PrettyPrinter(
      colors: false,
      printTime: true,
    ),
    output: MultiOutput([
      ConsoleOutput(),
      FileOutput(
        file: logFile,
      ),
    ]),
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
        size: Size(1280, 720),
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
        logger: logger,
        logFile: logFile,
      ));
    },
    (Object error, StackTrace stack) {
      logger.e('Dart Error', error, stack);
      exit(1);
    },
  );
}

class PathPlanner extends StatefulWidget {
  final FieldImage defaultField = FieldImage.official(OfficialField.RapidReact);
  final String appVersion = '2022.1.1';
  final bool appStoreBuild = false;
  final Logger logger;
  final File logFile;

  PathPlanner({required this.logger, required this.logFile, super.key});

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
      builder: (BuildContext context, Widget? w) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return AlertDialog(
            title: Text('PathPlanner encountered an error'),
            content: Container(
              constraints: BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: SelectableText(
                      errorDetails.exception.toString(),
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  SizedBox(height: 18),
                  Flexible(
                    child: SelectableText.rich(
                      TextSpan(
                        text:
                            'If you are going to report this error, please include the steps to reproduce and the log file located at: ',
                        children: [
                          TextSpan(
                            text: widget.logFile.path,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  exit(1);
                },
                child: Text('Exit'),
              ),
            ],
          );
        };
        if (w == null) return Container();
        return w;
      },
    );
  }
}
