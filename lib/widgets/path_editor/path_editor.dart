import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/services/generator/trajectory.dart';
import 'package:pathplanner/services/pplib_client.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/path_editor/editors/edit_editor.dart';
import 'package:pathplanner/widgets/path_editor/editors/graph_editor.dart';
import 'package:pathplanner/widgets/path_editor/editors/marker_editor.dart';
import 'package:pathplanner/widgets/path_editor/editors/measure_editor.dart';
import 'package:pathplanner/widgets/path_editor/editors/path_following_editor.dart';
import 'package:pathplanner/widgets/path_editor/editors/preview_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EditorMode {
  edit,
  preview,
  markers,
  measure,
  pathFollowing,
  graph,
}

class PathEditor extends StatefulWidget {
  final RobotPath path;
  final Size robotSize;
  final bool holonomicMode;
  final bool focusedSelection;
  final FieldImage fieldImage;
  final bool showGeneratorSettings;
  final void Function(RobotPath path) savePath;
  final SharedPreferences prefs;

  const PathEditor(
      {required this.fieldImage,
      required this.path,
      required this.robotSize,
      required this.holonomicMode,
      this.showGeneratorSettings = false,
      this.focusedSelection = false,
      required this.savePath,
      required this.prefs,
      super.key});

  @override
  State<PathEditor> createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  EditorMode _mode = EditorMode.edit;
  List<Point>? _activePath;
  TrajectoryState? _targetPose;
  TrajectoryState? _actualPose;
  bool _ppLibConnected = false;

  @override
  void initState() {
    super.initState();

    PPLibClient.setOnActivePathChanged((value) {
      setState(() {
        _activePath = value;
      });
    });

    PPLibClient.setOnPathFollowingDataChanged((p0, p1) {
      setState(() {
        _targetPose = p0;
        _actualPose = p1;
      });
    });

    PPLibClient.connectionStatusStream().listen((data) {
      if (!data && _mode == EditorMode.pathFollowing) {
        UndoRedo.clearHistory();
        setState(() {
          _mode = EditorMode.edit;
          _ppLibConnected = data;
        });
      } else {
        setState(() {
          _ppLibConnected = data;
        });
      }
    });
  }

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
      case EditorMode.edit:
        return EditEditor(
          path: widget.path,
          robotSize: widget.robotSize,
          holonomicMode: widget.holonomicMode,
          fieldImage: widget.fieldImage,
          showGeneratorSettings: widget.showGeneratorSettings,
          focusedSelection: widget.focusedSelection,
          savePath: widget.savePath,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
      case EditorMode.preview:
        return PreviewEditor(
          path: widget.path,
          fieldImage: widget.fieldImage,
          robotSize: widget.robotSize,
          holonomicMode: widget.holonomicMode,
          savePath: widget.savePath,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
      case EditorMode.markers:
        return MarkerEditor(
          path: widget.path,
          fieldImage: widget.fieldImage,
          robotSize: widget.robotSize,
          holonomicMode: widget.holonomicMode,
          savePath: widget.savePath,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
      case EditorMode.measure:
        return MeasureEditor(
          path: widget.path,
          fieldImage: widget.fieldImage,
          robotSize: widget.robotSize,
          holonomicMode: widget.holonomicMode,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
      case EditorMode.pathFollowing:
        return PathFollowingEditor(
          fieldImage: widget.fieldImage,
          robotSize: widget.robotSize,
          activePath: _activePath,
          targetPose: _targetPose,
          actualPose: _actualPose,
        );
      case EditorMode.graph:
        return GraphEditor(
          path: widget.path,
          holonomicMode: widget.holonomicMode,
          savePath: widget.savePath,
          prefs: widget.prefs,
          key: ValueKey(widget.path),
        );
    }
  }

  Widget _buildToolbar(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
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
                    onPressed: _mode == EditorMode.edit
                        ? null
                        : () {
                            UndoRedo.clearHistory();
                            setState(() {
                              _mode = EditorMode.edit;
                            });
                          },
                    child: const Icon(Icons.edit),
                  ),
                ),
                const VerticalDivider(width: 1),
                Tooltip(
                  message: 'Preview',
                  waitDuration: const Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    onPressed: _mode == EditorMode.preview
                        ? null
                        : () {
                            UndoRedo.clearHistory();
                            setState(() {
                              _mode = EditorMode.preview;
                            });
                          },
                    child: const Icon(Icons.play_arrow),
                  ),
                ),
                const VerticalDivider(width: 1),
                Tooltip(
                  message: 'Edit Markers',
                  waitDuration: const Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    onPressed: _mode == EditorMode.markers
                        ? null
                        : () {
                            UndoRedo.clearHistory();
                            setState(() {
                              _mode = EditorMode.markers;
                            });
                          },
                    child: const Icon(Icons.pin_drop),
                  ),
                ),
                const VerticalDivider(width: 1),
                Tooltip(
                  message: 'Measure',
                  waitDuration: const Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    onPressed: _mode == EditorMode.measure
                        ? null
                        : () {
                            UndoRedo.clearHistory();
                            setState(() {
                              _mode = EditorMode.measure;
                            });
                          },
                    child: const Icon(Icons.straighten),
                  ),
                ),
                const VerticalDivider(width: 1),
                Tooltip(
                    message: 'Graph Path',
                    waitDuration: const Duration(milliseconds: 500),
                    child: MaterialButton(
                      height: 50,
                      minWidth: 50,
                      onPressed: _mode == EditorMode.graph
                          ? null
                          : () {
                              UndoRedo.clearHistory();
                              setState(() {
                                _mode = EditorMode.graph;
                              });
                            },
                      child: const Icon(Icons.show_chart),
                    )),
                if (_ppLibConnected) const VerticalDivider(width: 1),
                if (_ppLibConnected)
                  Tooltip(
                    message: 'Path Following',
                    waitDuration: const Duration(milliseconds: 500),
                    child: MaterialButton(
                      height: 50,
                      minWidth: 50,
                      onPressed: _mode == EditorMode.pathFollowing
                          ? null
                          : () {
                              UndoRedo.clearHistory();
                              setState(() {
                                _mode = EditorMode.pathFollowing;
                              });
                            },
                      child: const Icon(Icons.route),
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
