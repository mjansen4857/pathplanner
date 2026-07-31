import 'package:flutter/material.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/pathplanner_auto.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_path2_auto_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class Path2AutoEditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final Path2Auto auto;
  final List<path2.Path> allPaths;
  final List<String> allPathNames;
  final FieldImage fieldImage;
  final ValueChanged<String> onRenamed;
  final ChangeStack undoStack;
  final bool shortcuts;
  final VoidCallback? onAutoChanged;

  const Path2AutoEditorPage({
    super.key,
    required this.prefs,
    required this.auto,
    required this.allPaths,
    required this.allPathNames,
    required this.fieldImage,
    required this.onRenamed,
    required this.undoStack,
    this.shortcuts = true,
    this.onAutoChanged,
  });

  @override
  State<Path2AutoEditorPage> createState() => _Path2AutoEditorPageState();
}

class _Path2AutoEditorPageState extends State<Path2AutoEditorPage> {
  @override
  void initState() {
    super.initState();
    if (widget.auto.initializeStartingPoseFromPaths(widget.allPaths)) {
      widget.auto.saveFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final editor = SplitPath2AutoEditor(
      prefs: widget.prefs,
      auto: widget.auto,
      allPaths: widget.allPaths,
      allPathNames: widget.allPathNames,
      fieldImage: widget.fieldImage,
      undoStack: widget.undoStack,
      onAutoChanged: () {
        widget.auto.initializeStartingPoseFromPaths(widget.allPaths);
        setState(widget.auto.saveFile);
        widget.onAutoChanged?.call();
      },
      onEditPathPressed: (pathName) {
        widget.undoStack.clearHistory();
        Navigator.of(context).pop(pathName);
      },
    );

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
            widget.onRenamed(value);
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
