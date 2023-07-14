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
  late bool _treeOnRight;

  @override
  void initState() {
    super.initState();

    _treeOnRight = widget.prefs.getBool(PrefsKeys.treeOnRight) ?? true;

    double treeWeight =
        widget.prefs.getDouble(PrefsKeys.editorTreeWeight) ?? 0.5;
    _controller.areas = [
      Area(
        weight: _treeOnRight ? (1.0 - treeWeight) : treeWeight,
        minimalWeight: 0.25,
      ),
      Area(
        weight: _treeOnRight ? treeWeight : (1.0 - treeWeight),
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
              double? newWeight = _treeOnRight
                  ? _controller.areas[1].weight
                  : _controller.areas[0].weight;
              widget.prefs
                  .setDouble(PrefsKeys.editorTreeWeight, newWeight ?? 0.5);
            },
            children: [
              if (_treeOnRight) Container(),
              Card(
                margin: const EdgeInsets.all(0),
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft:
                        _treeOnRight ? const Radius.circular(12) : Radius.zero,
                    topRight:
                        _treeOnRight ? Radius.zero : const Radius.circular(12),
                    bottomLeft:
                        _treeOnRight ? const Radius.circular(12) : Radius.zero,
                    bottomRight:
                        _treeOnRight ? Radius.zero : const Radius.circular(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: PathTree(
                    path: widget.path,
                    onPathChanged: () {
                      setState(() {
                        widget.path.generateAndSavePath();
                      });
                    },
                    onSideSwapped: () => setState(() {
                      _treeOnRight = !_treeOnRight;
                      widget.prefs.setBool(PrefsKeys.treeOnRight, _treeOnRight);
                      _controller.areas = _controller.areas.reversed.toList();
                    }),
                    onWaypointHover: (value) {
                      setState(() {
                        _hoveredWaypoint = value;
                      });
                    },
                  ),
                ),
              ),
              if (!_treeOnRight) Container(),
            ],
          ),
        ),
      ],
    );
  }
}
