import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pathplanner/pathfinding/nav_grid.dart';
import 'package:pathplanner/widgets/number_text_field.dart';

class EditNavGridDialog extends StatefulWidget {
  final NavGrid grid;
  final ValueChanged<NavGrid> onGridChange;

  const EditNavGridDialog(
      {super.key, required this.grid, required this.onGridChange});

  @override
  State<StatefulWidget> createState() => _EditNavGridDialogState();
}

class _EditNavGridDialogState extends State<EditNavGridDialog> {
  late num _nodeSize;
  late num _fieldLength;
  late num _fieldWidth;

  @override
  void initState() {
    super.initState();
    _nodeSize = widget.grid.nodeSizeMeters;
    // These are right...
    _fieldLength = widget.grid.fieldSize.width;
    _fieldWidth = widget.grid.fieldSize.height;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Grid'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: NumberTextField(
                  value: _nodeSize,
                  label: 'Node Size (M)',
                  arrowKeyIncrement: 0.05,
                  onSubmitted: (value) => (setState(() {
                    _nodeSize = value;
                  })),
                )),
              ],
            ),
            const Text(
                'Larger node size = more performance, but less accuracy'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: NumberTextField(
                  value: _fieldLength,
                  label: 'Field Length (M)',
                  arrowKeyIncrement: 0.01,
                  onSubmitted: (value) => (setState(() {
                    _fieldLength = value;
                  })),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: NumberTextField(
                  value: _fieldWidth,
                  label: 'Field Width (M)',
                  arrowKeyIncrement: 0.01,
                  onSubmitted: (value) => (setState(() {
                    _fieldWidth = value;
                  })),
                )),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
                'Note: Changing these attributes will clear the navgrid. This cannot be undone.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            String fileContent = await DefaultAssetBundle.of(this.context)
                .loadString('resources/default_navgrid.json');

            NavGrid grid = NavGrid.fromJson(jsonDecode(fileContent));
            widget.onGridChange(grid);

            if (mounted) {
              Navigator.of(this.context).pop();
            }
          },
          child: const Text('Restore Default'),
        ),
        TextButton(
          onPressed: () {
            NavGrid grid = NavGrid.blankGrid(
              nodeSizeMeters: _nodeSize,
              fieldSize: Size(_fieldLength.toDouble(), _fieldWidth.toDouble()),
            );
            widget.onGridChange(grid);
            Navigator.of(context).pop();
            // }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
