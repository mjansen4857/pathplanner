import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/editors/edit_editor.dart';
import 'package:pathplanner/widgets/path_editor/editors/marker_editor.dart';
import 'package:pathplanner/widgets/path_editor/editors/measure_editor.dart';
import 'package:pathplanner/widgets/path_editor/editors/preview_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EditorMode {
  Edit,
  Preview,
  Markers,
  Measure,
}

class PathEditor extends StatefulWidget {
  final RobotPath path;
  final Size robotSize;
  final bool holonomicMode;
  final FieldImage fieldImage;
  final bool showGeneratorSettings;
  final void Function(RobotPath path) savePath;
  final SharedPreferences prefs;

  PathEditor(
      {required this.fieldImage,
      required this.path,
      required this.robotSize,
      required this.holonomicMode,
      this.showGeneratorSettings = false,
      required this.savePath,
      required this.prefs,
      super.key});

  @override
  _PathEditorState createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  EditorMode _mode = EditorMode.Edit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildEditorMode(),
        _buildToolbar(context),
      ],
    );
  }

  Widget _buildEditorMode() {
    switch (_mode) {
      case EditorMode.Edit:
        return EditEditor(
          path: widget.path,
          robotSize: widget.robotSize,
          holonomicMode: widget.holonomicMode,
          fieldImage: widget.fieldImage,
          showGeneratorSettings: widget.showGeneratorSettings,
          savePath: widget.savePath,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
      case EditorMode.Preview:
        return PreviewEditor(
          path: widget.path,
          fieldImage: widget.fieldImage,
          robotSize: widget.robotSize,
          holonomicMode: widget.holonomicMode,
          savePath: widget.savePath,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
      case EditorMode.Markers:
        return MarkerEditor(
          path: widget.path,
          fieldImage: widget.fieldImage,
          robotSize: widget.robotSize,
          holonomicMode: widget.holonomicMode,
          savePath: widget.savePath,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
      case EditorMode.Measure:
        return MeasureEditor(
          path: widget.path,
          fieldImage: widget.fieldImage,
          robotSize: widget.robotSize,
          holonomicMode: widget.holonomicMode,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
    }
  }

  Widget _buildToolbar(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          height: 48,
          child: Card(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Edit Path',
                  waitDuration: const Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    child: Icon(Icons.edit),
                    textColor: colorScheme.onSurface,
                    onPressed: _mode == EditorMode.Edit
                        ? null
                        : () {
                            UndoRedo.clearHistory();
                            setState(() {
                              _mode = EditorMode.Edit;
                            });
                          },
                  ),
                ),
                VerticalDivider(width: 1),
                Tooltip(
                  message: 'Preview',
                  waitDuration: const Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    child: Icon(Icons.play_arrow),
                    textColor: colorScheme.onSurface,
                    onPressed: _mode == EditorMode.Preview
                        ? null
                        : () {
                            UndoRedo.clearHistory();
                            setState(() {
                              _mode = EditorMode.Preview;
                            });
                          },
                  ),
                ),
                VerticalDivider(width: 1),
                Tooltip(
                  message: 'Edit Markers',
                  waitDuration: const Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    child: Icon(Icons.pin_drop),
                    textColor: colorScheme.onSurface,
                    onPressed: _mode == EditorMode.Markers
                        ? null
                        : () {
                            UndoRedo.clearHistory();
                            setState(() {
                              _mode = EditorMode.Markers;
                            });
                          },
                  ),
                ),
                VerticalDivider(width: 1),
                Tooltip(
                  message: 'Measure',
                  waitDuration: const Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    child: Icon(Icons.straighten),
                    textColor: colorScheme.onSurface,
                    onPressed: _mode == EditorMode.Measure
                        ? null
                        : () {
                            UndoRedo.clearHistory();
                            setState(() {
                              _mode = EditorMode.Measure;
                            });
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
