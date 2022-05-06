import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/field_image.dart';

import 'pages/home_page.dart';

void main() {
  runApp(PathPlanner());

  if (Platform.isWindows || Platform.isLinux) {
    doWhenWindowReady(() {
      appWindow.minSize = Size(900, 600);
      appWindow.size = Size(1280, 720);
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }
}

class PathPlanner extends StatelessWidget {
  final FieldImage defaultField = FieldImage.official(OfficialField.RapidReact);
  final String appVersion = '2022.1.1';
  final bool appStoreBuild = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.indigo,
    );

    return MaterialApp(
      title: 'PathPlanner',
      theme: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          secondary: Colors.white,
        ),
      ),
      home: HomePage(
        defaultField,
        appVersion: appVersion,
        appStoreBuild: appStoreBuild,
      ),
    );
  }
}
