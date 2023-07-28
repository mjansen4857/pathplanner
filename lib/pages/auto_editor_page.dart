import 'package:flutter/material.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_auto_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class AutoEditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final PathPlannerAuto auto;
  final List<PathPlannerPath> allPaths;
  final List<String> allPathNames;
  final FieldImage fieldImage;
  final ValueChanged<String> onRenamed;
  final ChangeStack undoStack;

  const AutoEditorPage({
    super.key,
    required this.prefs,
    required this.auto,
    required this.allPaths,
    required this.allPathNames,
    required this.fieldImage,
    required this.onRenamed,
    required this.undoStack,
  });

  @override
  State<AutoEditorPage> createState() => _AutoEditorPageState();
}

class _AutoEditorPageState extends State<AutoEditorPage> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    List<String> autoPathNames = widget.auto.getAllPathNames();
    List<PathPlannerPath> autoPaths = autoPathNames
        .map((name) => widget.allPaths.firstWhere((path) => path.name == name))
        .toList();

    return Scaffold(
      appBar: CustomAppBar(
        titleWidget: RenamableTitle(
          title: widget.auto.name,
          textStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          onRename: (value) {
            widget.onRenamed.call(value);
            setState(() {});
          },
        ),
        leading: BackButton(
          onPressed: () {
            widget.undoStack.clearHistory();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: KeyBoardShortcuts(
        keysToPress: shortCut(BasicShortCuts.undo),
        onKeysPressed: widget.undoStack.undo,
        child: KeyBoardShortcuts(
          keysToPress: shortCut(BasicShortCuts.redo),
          onKeysPressed: widget.undoStack.redo,
          child: SplitAutoEditor(
            prefs: widget.prefs,
            auto: widget.auto,
            autoPaths: autoPaths,
            allPathNames: widget.allPathNames,
            fieldImage: widget.fieldImage,
            undoStack: widget.undoStack,
            onAutoChanged: () {
              setState(() {
                widget.auto.saveFile();
              });
            },
          ),
        ),
      ),
    );
  }
}
