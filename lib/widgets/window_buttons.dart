import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowButton extends StatefulWidget {
  final double buttonWidth;
  final Color hoverBackgroundColor;
  final Color pressedBackgroundColor;
  final VoidCallback onPressed;
  final IconData icon;
  final EdgeInsets padding;

  const WindowButton({
    this.buttonWidth = 56,
    this.hoverBackgroundColor = const Color(0xFF404040),
    this.pressedBackgroundColor = const Color(0xFF202020),
    required this.onPressed,
    required this.icon,
    this.padding = const EdgeInsets.all(8),
    super.key,
  });

  @override
  State<WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return MouseStateBuilder(
      builder: (context, mouseState) {
        Color? backgroundColor;
        if (mouseState.isMouseDown) {
          backgroundColor = widget.pressedBackgroundColor;
        }
        if (mouseState.isMouseOver) {
          backgroundColor = widget.hoverBackgroundColor;
        }

        return SizedBox(
          width: widget.buttonWidth,
          child: Container(
            color: backgroundColor ?? Colors.transparent,
            child: Padding(
              padding: widget.padding,
              child: Icon(
                widget.icon,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
      onPressed: widget.onPressed,
    );
  }
}

class MinimizeWindowButton extends WindowButton {
  MinimizeWindowButton({super.key})
      : super(
          icon: Icons.minimize,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          onPressed: () {
            windowManager.minimize();
          },
        );
}

class MaximizeWindowButton extends WindowButton {
  MaximizeWindowButton({super.key})
      : super(
          icon: Icons.check_box_outline_blank,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        );
}

class CloseWindowButton extends WindowButton {
  CloseWindowButton({super.key})
      : super(
          icon: Icons.close,
          hoverBackgroundColor: const Color(0xFFD32F2F),
          pressedBackgroundColor: const Color(0xFFD32F2F),
          onPressed: () {
            windowManager.close();
          },
        );
}

typedef MouseStateBuilderCB = Widget Function(
    BuildContext context, MouseState mouseState);

class MouseState {
  bool isMouseOver = false;
  bool isMouseDown = false;
  MouseState();
  @override
  String toString() {
    return 'isMouseDown: $isMouseDown - isMouseOver: $isMouseOver';
  }
}

class MouseStateBuilder extends StatefulWidget {
  final MouseStateBuilderCB? builder;
  final VoidCallback? onPressed;

  const MouseStateBuilder({Key? key, this.builder, this.onPressed})
      : super(key: key);

  @override
  State<MouseStateBuilder> createState() => _MouseStateBuilderState();
}

class _MouseStateBuilderState extends State<MouseStateBuilder> {
  late MouseState _mouseState;
  _MouseStateBuilderState() {
    _mouseState = MouseState();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
        onEnter: (event) {
          setState(() {
            _mouseState.isMouseOver = true;
          });
        },
        onExit: (event) {
          setState(() {
            _mouseState.isMouseOver = false;
          });
        },
        child: GestureDetector(
            onTapDown: (_) {
              setState(() {
                _mouseState.isMouseDown = true;
              });
            },
            onTapCancel: () {
              setState(() {
                _mouseState.isMouseDown = false;
              });
            },
            onTap: () {
              setState(() {
                _mouseState.isMouseDown = false;
                _mouseState.isMouseOver = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.onPressed != null) {
                  widget.onPressed!();
                }
              });
            },
            onTapUp: (_) {},
            child: widget.builder!(context, _mouseState)));
  }
}
