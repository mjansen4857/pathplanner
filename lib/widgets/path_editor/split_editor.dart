import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplitEditor extends StatefulWidget {
  final SharedPreferences prefs;

  const SplitEditor({
    required this.prefs,
    super.key,
  });

  @override
  State<SplitEditor> createState() => _SplitEditorState();
}

class _SplitEditorState extends State<SplitEditor> {
  final MultiSplitViewController _controller = MultiSplitViewController();

  @override
  void initState() {
    super.initState();

    double leftWeight = widget.prefs.getDouble('editorLeftWeight') ?? 0.5;
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

    return MultiSplitViewTheme(
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
          widget.prefs.setDouble(
              'editorLeftWeight', _controller.areas[0].weight ?? 0.5);
        },
        children: const [
          Placeholder(),
          Placeholder(),
        ],
      ),
    );
  }
}
