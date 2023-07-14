import 'package:flutter/material.dart';
import 'package:flutter_simple_treeview/flutter_simple_treeview.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/prefs_keys.dart';
import 'package:pathplanner/widgets/editor/path_painter.dart';
import 'package:pathplanner/widgets/editor/path_tree.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplitEditor extends StatefulWidget {
  final SharedPreferences prefs;
  final PathPlannerPath path;
  final FieldImage fieldImage;

  const SplitEditor({
    required this.prefs,
    required this.path,
    required this.fieldImage,
    super.key,
  });

  @override
  State<SplitEditor> createState() => _SplitEditorState();
}

class _SplitEditorState extends State<SplitEditor> {
  final MultiSplitViewController _controller = MultiSplitViewController();
  int? _hoveredWaypoint;

  @override
  void initState() {
    super.initState();

    double leftWeight =
        widget.prefs.getDouble(PrefsKeys.editorLeftWeight) ?? 0.5;
    _controller.areas = [
      Area(
        weight: leftWeight,
        minimalWeight: 0.25,
      ),
      Area(
        weight: 1.0 - leftWeight,
        minimalWeight: 0.25,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Stack(
                children: [
                  widget.fieldImage.getWidget(),
                  Positioned.fill(
                    child: PathPainter(
                      path: widget.path,
                      fieldImage: widget.fieldImage,
                      hoveredWaypoint: _hoveredWaypoint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        MultiSplitViewTheme(
          data: MultiSplitViewThemeData(
            dividerPainter: DividerPainters.grooved1(
              color: colorScheme.surfaceVariant,
              highlightedColor: colorScheme.primary,
            ),
          ),
          child: MultiSplitView(
            axis: Axis.horizontal,
            controller: _controller,
            onWeightChange: () {
              widget.prefs.setDouble(PrefsKeys.editorLeftWeight,
                  _controller.areas[0].weight ?? 0.5);
            },
            children: [
              Container(),
              Card(
                margin: const EdgeInsets.all(0),
                elevation: 4.0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: PathTree(
                    path: widget.path,
                    onWaypointHover: (value) {
                      setState(() {
                        _hoveredWaypoint = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
