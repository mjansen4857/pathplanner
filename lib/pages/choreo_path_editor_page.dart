import 'package:flutter/material.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_choreo_path_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class ChoreoPathEditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final ChoreoPath path;
  final FieldImage fieldImage;
  final ChangeStack undoStack;
  final bool shortcuts;
  final bool simulatePath;

  const ChoreoPathEditorPage({
    super.key,
    required this.prefs,
    required this.path,
    required this.fieldImage,
    required this.undoStack,
    this.shortcuts = true,
    this.simulatePath = false,
  });

  @override
  State<ChoreoPathEditorPage> createState() => _ChoreoPathEditorPageState();
}

class _ChoreoPathEditorPageState extends State<ChoreoPathEditorPage> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    final editorWidget = SplitChoreoPathEditor(
      prefs: widget.prefs,
      path: widget.path,
      fieldImage: widget.fieldImage,
      undoStack: widget.undoStack,
      simulate: widget.simulatePath,
    );

    return Scaffold(
      appBar: CustomAppBar(
        titleWidget: Text(
          widget.path.name,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        leading: BackButton(
          onPressed: () {
            widget.undoStack.clearHistory();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ConditionalWidget(
        condition: widget.shortcuts,
        trueChild: KeyBoardShortcuts(
          keysToPress: shortCut(BasicShortCuts.undo),
          onKeysPressed: widget.undoStack.undo,
          child: KeyBoardShortcuts(
            keysToPress: shortCut(BasicShortCuts.redo),
            onKeysPressed: widget.undoStack.redo,
            child: editorWidget,
          ),
        ),
        falseChild: editorWidget,
      ),
    );
  }
}
