import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  runApp(PathPlanner());

  doWhenWindowReady(() {
    appWindow.minSize = Size(900, 600);
    appWindow.size = Size(1280, 720);
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class PathPlanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PathPlanner',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
      ),
      home: HomePage(),
    );
  }
}
