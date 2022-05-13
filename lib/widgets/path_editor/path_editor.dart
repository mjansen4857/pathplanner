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
  final void Function(RobotPath path)? savePath;
  final SharedPreferences? prefs;

  PathEditor(this.fieldImage, this.path, this.robotSize, this.holonomicMode,
      {this.showGeneratorSettings = false, this.savePath, this.prefs});

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
          widget.path,
          widget.robotSize,
          widget.holonomicMode,
          widget.fieldImage,
          showGeneratorSettings: widget.showGeneratorSettings,
          savePath: widget.savePath,
          prefs: widget.prefs,
        );
      case EditorMode.Preview:
        return PreviewEditor(
          widget.path,
          widget.fieldImage,
          widget.robotSize,
          widget.holonomicMode,
          savePath: widget.savePath,
          prefs: widget.prefs,
        );
      case EditorMode.Markers:
        return MarkerEditor(
          widget.path,
          widget.fieldImage,
          widget.robotSize,
          widget.holonomicMode,
          savePath: widget.savePath,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
      case EditorMode.Measure:
        return MeasureEditor(
          widget.path,
          widget.fieldImage,
          widget.robotSize,
          widget.holonomicMode,
          prefs: widget.prefs,
        );
    }
  }

  Widget _buildToolbar(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          height: 48,
          child: Card(
            color: Theme.of(context).colorScheme.surfaceVariant,
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
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
