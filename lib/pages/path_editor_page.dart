import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_path_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class PathEditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final PathPlannerPath path;
  final FieldImage fieldImage;
  final ValueChanged<String> onRenamed;
  final ChangeStack undoStack;
  final bool shortcuts;
  final PPLibTelemetry? telemetry;
  final bool hotReload;
  final bool simulatePath;
  final VoidCallback? onPathChanged;

  const PathEditorPage({
    super.key,
    required this.prefs,
    required this.path,
    required this.fieldImage,
    required this.onRenamed,
    required this.undoStack,
    this.shortcuts = true,
    this.telemetry,
    this.hotReload = false,
    this.simulatePath = false,
    this.onPathChanged,
  });

  @override
  State<PathEditorPage> createState() => _PathEditorPageState();
}

class _PathEditorPageState extends State<PathEditorPage> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    final editorWidget = SplitPathEditor(
      prefs: widget.prefs,
      path: widget.path,
      fieldImage: widget.fieldImage,
      undoStack: widget.undoStack,
      telemetry: widget.telemetry,
      hotReload: widget.hotReload,
      simulate: widget.simulatePath,
      onPathChanged: widget.onPathChanged,
    );

    return Scaffold(
      appBar: CustomAppBar(
        titleWidget: RenamableTitle(
          title: widget.path.name,
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
