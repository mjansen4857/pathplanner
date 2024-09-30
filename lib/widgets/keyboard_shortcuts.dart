import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';

List<_KeyBoardShortcuts> _keyBoardShortcuts = [];

enum BasicShortCuts {
  creation,
  previousPage,
  nextPage,
  save,
  undo,
  redo,
}

bool _isPressed(
    Set<LogicalKeyboardKey> keysPressed, Set<LogicalKeyboardKey> keysToPress) {
  //when we type shift on chrome flutter's core return two pressed keys : Shift Left && Shift Right. So we need to delete one on the set to run the action
  keysToPress = LogicalKeyboardKey.collapseSynonyms(keysToPress);
  keysPressed = LogicalKeyboardKey.collapseSynonyms(keysPressed);

  return keysPressed.containsAll(keysToPress) &&
      keysPressed.length == keysToPress.length;
}

class KeyBoardShortcuts extends StatefulWidget {
  final Widget child;

  /// You can use shortCut function with BasicShortCuts to avoid write data by yourself
  final Set<LogicalKeyboardKey>? keysToPress;

  /// Function when keys are pressed
  final VoidCallback? onKeysPressed;

  const KeyBoardShortcuts(
      {this.keysToPress, this.onKeysPressed, required this.child, super.key});

  @override
  State<KeyBoardShortcuts> createState() => _KeyBoardShortcuts();
}

class _KeyBoardShortcuts extends State<KeyBoardShortcuts> {
  FocusScopeNode? focusScopeNode;
  final ScrollController _controller = ScrollController();
  bool controllerIsReady = false;
  bool listening = false;
  late Key key;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      if (_controller.hasClients) setState(() => controllerIsReady = true);
    });
    _attachKeyboardIfDetached();
    key = widget.key ?? UniqueKey();
  }

  @override
  void dispose() {
    focusScopeNode?.dispose();
    _controller.dispose();
    _detachKeyboardIfAttached();

    super.dispose();
  }

  void _attachKeyboardIfDetached() {
    if (listening) return;
    _keyBoardShortcuts.add(this);
    HardwareKeyboard.instance.addHandler(listener);
    listening = true;
  }

  void _detachKeyboardIfAttached() {
    if (!listening) return;
    _keyBoardShortcuts.remove(this);
    HardwareKeyboard.instance.removeHandler(listener);
    listening = false;
  }

  bool listener(KeyEvent v) {
    if (!mounted) return false;

    Set<LogicalKeyboardKey> keysPressed =
        HardwareKeyboard.instance.logicalKeysPressed;
    if (v.runtimeType == KeyDownEvent) {
      // when user type keysToPress
      if (widget.keysToPress != null &&
          widget.onKeysPressed != null &&
          _isPressed(keysPressed, widget.keysToPress!)) {
        widget.onKeysPressed!();
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: key,
      child:
          PrimaryScrollController(controller: _controller, child: widget.child),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction == 1) {
          _attachKeyboardIfDetached();
        } else {
          _detachKeyboardIfAttached();
        }
      },
    );
  }
}

Set<LogicalKeyboardKey> shortCut(BasicShortCuts basicShortCuts) {
  switch (basicShortCuts) {
    case BasicShortCuts.undo:
      if (Platform.isMacOS) {
        return {LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ};
      } else {
        return {LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ};
      }
    case BasicShortCuts.redo:
      if (Platform.isMacOS) {
        return {LogicalKeyboardKey.meta, LogicalKeyboardKey.keyY};
      } else {
        return {LogicalKeyboardKey.control, LogicalKeyboardKey.keyY};
      }
    case BasicShortCuts.creation:
      return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyN};
    case BasicShortCuts.previousPage:
      return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowLeft};
    case BasicShortCuts.nextPage:
      return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowRight};
    case BasicShortCuts.save:
      return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyS};
    default:
      return {};
  }
}
