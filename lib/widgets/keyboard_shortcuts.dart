import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';
import 'package:visibility_detector/visibility_detector.dart';

Widget? _homeWidget;
List<_KeyBoardShortcuts> _keyBoardShortcuts = [];
Widget? _customGlobal;
String? _customTitle;
IconData? _customIcon;
bool _helperIsOpen = false;
List<Tuple3<Set<LogicalKeyboardKey>, Function(BuildContext context), String>>
    _newGlobal = [];

enum BasicShortCuts {
  creation,
  previousPage,
  nextPage,
  save,
}

void initShortCuts(
  Widget homePage, {
  Set<Set<LogicalKeyboardKey>>? keysToPress,
  Set<Function(BuildContext context)>? onKeysPressed,
  Set<String>? helpLabel,
  Widget? helpGlobal,
  String? helpTitle,
  IconData? helpIcon,
}) async {
  if (keysToPress != null &&
      onKeysPressed != null &&
      helpLabel != null &&
      keysToPress.length == onKeysPressed.length &&
      onKeysPressed.length == helpLabel.length) {
    _newGlobal = [];
    for (var i = 0; i < keysToPress.length; i++) {
      _newGlobal.add(Tuple3(keysToPress.elementAt(i),
          onKeysPressed.elementAt(i), helpLabel.elementAt(i)));
    }
  }
  _homeWidget = homePage;
  _customGlobal = helpGlobal;
  _customTitle = helpTitle;
  _customIcon = helpIcon;
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

  /// Label who will be displayed in helper
  final String? helpLabel;

  /// Activate when this widget is the first of the page
  final bool globalShortcuts;

  const KeyBoardShortcuts(
      {this.keysToPress,
      this.onKeysPressed,
      this.helpLabel,
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
    _controller.addListener(() {
      if (_controller.hasClients) setState(() => controllerIsReady = true);
    });
    _attachKeyboardIfDetached();
    key = widget.key ?? UniqueKey();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _detachKeyboardIfAttached();
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
    if (!mounted || _helperIsOpen) return;

    Set<LogicalKeyboardKey> keysPressed = RawKeyboard.instance.keysPressed;
    if (v.runtimeType == RawKeyDownEvent) {
      // when user type keysToPress
      if (widget.keysToPress != null &&
          widget.onKeysPressed != null &&
          _isPressed(keysPressed, widget.keysToPress!)) {
        widget.onKeysPressed!();
      }

      // when user request help menu
      else if (_isPressed(keysPressed,
          {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyH})) {
        List<Widget> activeHelp = [];

        //verify if element is visible or not
        List<_KeyBoardShortcuts> toRemove = [];
        for (var element in _keyBoardShortcuts) {
          if (VisibilityDetectorController.instance
                  .widgetBoundsFor(element.key) ==
              null) {
            element.listening = false;
            toRemove.add(element);
          }
        }

        _keyBoardShortcuts.removeWhere((element) => toRemove.contains(element));
        for (var element in _keyBoardShortcuts) {
          Widget? elementWidget = _helpWidget(element);
          if (elementWidget != null) activeHelp.add(elementWidget);
        } // get all custom shortcuts

        bool showGlobalShort =
            _keyBoardShortcuts.any((element) => element.widget.globalShortcuts);

        if (!_helperIsOpen && (activeHelp.isNotEmpty || showGlobalShort)) {
          _helperIsOpen = true;

          await showDialog<void>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              key: UniqueKey(),
              title: Text(_customTitle ?? 'Keyboard Shortcuts'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget?>[
                    if (activeHelp.isNotEmpty)
                      ListBody(
                        children: [
                          for (final i in activeHelp) i,
                          const Divider(),
                        ],
                      ),
                    if (showGlobalShort)
                      _customGlobal ??
                          ListBody(
                            children: [
                              for (final newElement in _newGlobal)
                                ListTile(
                                  leading: Icon(_customIcon ?? Icons.settings),
                                  title: Text(newElement.item3),
                                  subtitle:
                                      Text(_getKeysToPress(newElement.item1)),
                                ),
                              ListTile(
                                leading: const Icon(Icons.home),
                                title: const Text('Go on Home page'),
                                subtitle:
                                    Text(LogicalKeyboardKey.home.debugName!),
                              ),
                              ListTile(
                                leading:
                                    const Icon(Icons.subdirectory_arrow_left),
                                title: const Text('Go on last page'),
                                subtitle:
                                    Text(LogicalKeyboardKey.escape.debugName!),
                              ),
                              ListTile(
                                leading: const Icon(Icons.keyboard_arrow_up),
                                title: const Text('Scroll to top'),
                                subtitle:
                                    Text(LogicalKeyboardKey.pageUp.debugName!),
                              ),
                              ListTile(
                                leading: const Icon(Icons.keyboard_arrow_down),
                                title: const Text('Scroll to bottom'),
                                subtitle: Text(
                                    LogicalKeyboardKey.pageDown.debugName!),
                              ),
                            ],
                          ),
                  ] as List<Widget>,
                ),
              ),
            ),
          ).then((value) => _helperIsOpen = false);
        }
      } else if (widget.globalShortcuts) {
        if (_homeWidget != null &&
            _isPressed(keysPressed, {LogicalKeyboardKey.home})) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => _homeWidget!),
              (_) => false);
        } else if (_isPressed(keysPressed, {LogicalKeyboardKey.escape})) {
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

String _getKeysToPress(Set<LogicalKeyboardKey>? keysToPress) {
  String text = '';
  if (keysToPress != null) {
    for (final i in keysToPress) {
      text += '${i.debugName!} + ';
    }
    text = text.substring(0, text.lastIndexOf(' + '));
  }
  return text;
}

Widget? _helpWidget(_KeyBoardShortcuts widget) {
  String text = _getKeysToPress(widget.widget.keysToPress);
  if (widget.widget.helpLabel != null && text != '') {
    return ListTile(
      leading: Icon(_customIcon ?? Icons.settings),
      title: Text(widget.widget.helpLabel!),
      subtitle: Text(text),
    );
  }
  return null;
}

Set<LogicalKeyboardKey> shortCut(BasicShortCuts basicShortCuts) {
  switch (basicShortCuts) {
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
