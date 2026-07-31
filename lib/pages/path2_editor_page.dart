import 'package:flutter/material.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_path2_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class Path2EditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final path2.Path path;
  final FieldImage fieldImage;
  final ValueChanged<String> onRenamed;
  final ChangeStack undoStack;
  final bool shortcuts;
  final VoidCallback? onPathChanged;

  const Path2EditorPage({
    super.key,
    required this.prefs,
    required this.path,
    required this.fieldImage,
    required this.onRenamed,
    required this.undoStack,
    this.shortcuts = true,
    this.onPathChanged,
  });

  @override
  State<Path2EditorPage> createState() => _Path2EditorPageState();
}

class _Path2EditorPageState extends State<Path2EditorPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final editor = SplitPath2Editor(
      prefs: widget.prefs,
      path: widget.path,
      fieldImage: widget.fieldImage,
      undoStack: widget.undoStack,
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
          onRename: (name) {
            widget.onRenamed(name);
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
            child: editor,
          ),
        ),
        falseChild: editor,
      ),
    );
  }
}
