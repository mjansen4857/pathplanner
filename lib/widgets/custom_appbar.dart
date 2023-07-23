import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'window_buttons.dart';

class CustomAppBar extends AppBar {
  final Widget titleWidget;
  final bool pplibClient;

  CustomAppBar(
      {this.titleWidget = const Text('PathPlanner'),
      this.pplibClient = false,
      super.key,
      super.leading,
      super.automaticallyImplyLeading})
      : super(
          actions: [
            if (pplibClient)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: StreamBuilder<bool>(
                  initialData: false, // TODO
                  builder: (context, snapshot) {
                    bool connected = snapshot.hasData ? snapshot.data! : false;

                    if (connected) {
                      return const Tooltip(
                        message: 'Connected to Robot',
                        child: Icon(
                          Icons.lan,
                          color: Colors.green,
                        ),
                      );
                    } else {
                      return const Tooltip(
                        message: 'Not Connected to Robot',
                        child: Icon(
                          Icons.lan,
                          color: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            if (!Platform.isMacOS) MinimizeWindowButton(),
            if (!Platform.isMacOS) MaximizeWindowButton(),
            if (!Platform.isMacOS) CloseWindowButton(),
          ],
          title: SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: _MoveWindowArea(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: titleWidget,
                    ),
                  ),
                ),
              ],
            ),
          ),
          elevation: 1,
        );
}

class _MoveWindowArea extends StatelessWidget {
  final Widget? child;

  const _MoveWindowArea({this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        windowManager.startDragging();
      },
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: child ?? Container(),
    );
  }
}
