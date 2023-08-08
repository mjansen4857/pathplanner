import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';
import 'package:visibility_detector/visibility_detector.dart';

List<_KeyBoardShortcuts> _keyBoardShortcuts = [];
List<Tuple2<Set<LogicalKeyboardKey>, Function(BuildContext context)>>
    _newGlobal = [];

enum BasicShortCuts {
  creation,
  previousPage,
  nextPage,
  save,
  undo,
  redo,
}

void initShortCuts({
  Set<Set<LogicalKeyboardKey>>? keysToPress,
  Set<Function(BuildContext context)>? onKeysPressed,
}) async {
  if (keysToPress != null &&
      onKeysPressed != null &&
      keysToPress.length == onKeysPressed.length) {
    _newGlobal = [];
    for (var i = 0; i < keysToPress.length; i++) {
      _newGlobal
          .add(Tuple2(keysToPress.elementAt(i), onKeysPressed.elementAt(i)));
    }
  }
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

  /// Activate when this widget is the first of the page
  final bool globalShortcuts;

  const KeyBoardShortcuts(
      {this.keysToPress,
      this.onKeysPressed,
      this.globalShortcuts = false,
      required this.child,
      super.key});

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
    RawKeyboard.instance.addListener(listener);
    listening = true;
  }

  void _detachKeyboardIfAttached() {
    if (!listening) return;
    _keyBoardShortcuts.remove(this);
    RawKeyboard.instance.removeListener(listener);
    listening = false;
  }

  void listener(RawKeyEvent v) async {
    if (!mounted) return;

    Set<LogicalKeyboardKey> keysPressed = RawKeyboard.instance.keysPressed;
    if (v.runtimeType == RawKeyDownEvent) {
      // when user type keysToPress
      if (widget.keysToPress != null &&
          widget.onKeysPressed != null &&
          _isPressed(keysPressed, widget.keysToPress!)) {
        widget.onKeysPressed!();
      } else if (widget.globalShortcuts) {
        if (_isPressed(keysPressed, {LogicalKeyboardKey.escape})) {
          Navigator.maybePop(context);
        } else if (controllerIsReady &&
                keysPressed.containsAll({LogicalKeyboardKey.pageDown}) ||
            keysPressed.first.keyId == 0x10700000022) {
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
          );
        } else if (controllerIsReady &&
                keysPressed.containsAll({LogicalKeyboardKey.pageUp}) ||
            keysPressed.first.keyId == 0x10700000021) {
          _controller.animateTo(
            _controller.position.minScrollExtent,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
          );
        }
        for (final newElement in _newGlobal) {
          if (_isPressed(keysPressed, newElement.item1)) {
            newElement.item2(context);
            return;
          }
        }
      }
    }
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
