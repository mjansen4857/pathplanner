import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/field_image.dart';
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

class PathPlanner extends StatelessWidget {
  final FieldImage defaultField = FieldImage.official(OfficialField.RapidReact);
  final String appVersion = '2022.1.1';
  final bool appStoreBuild = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'PathPlanner',
      theme: theme,
      home: HomePage(
        defaultFieldImage: defaultField,
        appVersion: appVersion,
        appStoreBuild: appStoreBuild,
      ),
    );
  }
}
