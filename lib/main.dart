import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

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

  runApp(PathPlanner());
}

class PathPlanner extends StatefulWidget {
  final FieldImage defaultField = FieldImage.official(OfficialField.RapidReact);
  final String appVersion = '2022.1.1';
  final bool appStoreBuild = false;

  PathPlanner({super.key});

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
