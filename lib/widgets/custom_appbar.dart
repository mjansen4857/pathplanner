import 'package:flutter/material.dart';
import 'package:pathplanner/coderunner/platform/platform_shim.dart';
import 'package:pathplanner/coderunner/web_mode.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pathplanner/widgets/window_buttons.dart';

class CustomAppBar extends AppBar {
  final Widget titleWidget;

  CustomAppBar({
    this.titleWidget = const Text('PathPlanner'),
    super.key,
    super.leading,
    super.automaticallyImplyLeading,
  }) : super(
          actions: [
            if (!CodeRunnerWebMode.enabled && !PlatformShim.isMacOS)
              MinimizeWindowButton(),
            if (!CodeRunnerWebMode.enabled && !PlatformShim.isMacOS)
              MaximizeWindowButton(),
            if (!CodeRunnerWebMode.enabled && !PlatformShim.isMacOS)
              CloseWindowButton(),
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
    if (CodeRunnerWebMode.enabled) {
      return child ?? Container();
    }

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
