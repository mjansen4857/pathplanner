import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/pages/editor_page.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/prefs_keys.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectPage extends StatefulWidget {
  final SharedPreferences prefs;
  final FieldImage fieldImage;

  const ProjectPage({
    super.key,
    required this.prefs,
    required this.fieldImage,
  });

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final MultiSplitViewController _controller = MultiSplitViewController();
  List<PathPlannerPath> _paths = List.generate(
      10, (index) => PathPlannerPath.defaultPath(name: 'Path $index'));
  int _pathGridCount = 2;

  @override
  void initState() {
    super.initState();

    double leftWeight =
        widget.prefs.getDouble(PrefsKeys.projectLeftWeight) ?? 0.5;
    _pathGridCount = _getCrossAxisCountForWeight(leftWeight);
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0.0),
      child: MultiSplitViewTheme(
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
            setState(() {
              _pathGridCount =
                  _getCrossAxisCountForWeight(_controller.areas[0].weight!);
            });
            widget.prefs.setDouble(PrefsKeys.projectLeftWeight,
                _controller.areas[0].weight ?? 0.5);
          },
          children: [
            _buildPathsGrid(),
            _buildAutosGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildPathsGrid() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Paths',
                style: TextStyle(fontSize: 32),
              ),
              Expanded(child: Container()),
              FloatingActionButton.extended(
                heroTag: 'newPathBtn',
                onPressed: () {},
                label: const Text('New Path'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: GridView.count(
              crossAxisCount: _pathGridCount,
              childAspectRatio: 1.55,
              children: [
                for (PathPlannerPath path in _paths)
                  ProjectItemCard(
                    name: path.name,
                    fieldImage: widget.fieldImage,
                    path: path,
                    onOpened: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditorPage(
                            prefs: widget.prefs,
                            path: path,
                            fieldImage: widget.fieldImage,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getCrossAxisCountForWeight(double weight) {
    if (weight < 0.4) {
      return 1;
    } else if (weight < 0.6) {
      return 2;
    } else {
      return 3;
    }
  }

  Widget _buildAutosGrid() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Autos',
                style: TextStyle(fontSize: 32),
              ),
              Expanded(child: Container()),
              FloatingActionButton.extended(
                heroTag: 'newAutoBtn',
                onPressed: () {},
                label: const Text('New Auto'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4 - _pathGridCount,
              childAspectRatio: 1.55,
              children: List.generate(5, (index) => const Card()),
            ),
          ),
        ],
      ),
    );
  }
}
