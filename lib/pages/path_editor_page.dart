import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_path_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PathEditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final PathPlannerPath path;
  final FieldImage fieldImage;
  final ValueChanged<String> onRenamed;

  const PathEditorPage({
    super.key,
    required this.prefs,
    required this.path,
    required this.fieldImage,
    required this.onRenamed,
  });

  @override
  State<PathEditorPage> createState() => _PathEditorPageState();
}

class _PathEditorPageState extends State<PathEditorPage> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

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
            UndoRedo.clearHistory();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: KeyBoardShortcuts(
        keysToPress: shortCut(BasicShortCuts.undo),
        onKeysPressed: UndoRedo.undo,
        child: KeyBoardShortcuts(
          keysToPress: shortCut(BasicShortCuts.redo),
          onKeysPressed: UndoRedo.redo,
          child: SplitPathEditor(
            prefs: widget.prefs,
            path: widget.path,
            fieldImage: widget.fieldImage,
          ),
        ),
      ),
    );
  }
}
