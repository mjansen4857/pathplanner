import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditorPage extends StatelessWidget {
  final SharedPreferences prefs;
  final PathPlannerPath path;
  final FieldImage fieldImage;

  const EditorPage({
    super.key,
    required this.prefs,
    required this.path,
    required this.fieldImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        titleText: path.name,
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
          child: SplitEditor(
            prefs: prefs,
            path: path,
            fieldImage: fieldImage,
          ),
        ),
      ),
    );
  }
}
