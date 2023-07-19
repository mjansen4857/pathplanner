import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/mini_path_preview.dart';
import 'package:pathplanner/widgets/renamable_title.dart';

class ProjectItemCard extends StatefulWidget {
  final String name;
  final FieldImage fieldImage;
  final PathPlannerPath path;
  final VoidCallback onOpened;
  final VoidCallback onDuplicated;
  final VoidCallback onDeleted;
  final ValueChanged<String> onRenamed;

  const ProjectItemCard({
    super.key,
    required this.name,
    required this.fieldImage,
    required this.path,
    required this.onOpened,
    required this.onDuplicated,
    required this.onDeleted,
    required this.onRenamed,
  });

  @override
  State<ProjectItemCard> createState() => _ProjectItemCardState();
}

class _ProjectItemCardState extends State<ProjectItemCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              height: 38,
              color: Colors.white.withOpacity(0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tooltip(
                    message: 'Duplicate',
                    waitDuration: const Duration(seconds: 1),
                    child: FittedBox(
                      child: IconButton(
                        onPressed: widget.onDuplicated,
                        icon: const Icon(Icons.copy),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RenamableTitle(
                        title: widget.name,
                        textStyle: const TextStyle(fontSize: 28),
                        onRename: widget.onRenamed,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Delete',
                    waitDuration: const Duration(seconds: 1),
                    child: FittedBox(
                      child: IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Delete Path'),
                                content: Text(
                                    'Are you sure you want to delete the path: ${widget.name}? This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('CANCEL'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onDeleted.call();
                                    },
                                    child: const Text('DELETE'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.delete_forever),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (event) => setState(() {
                _hovering = true;
              }),
              onExit: (event) => setState(() {
                _hovering = false;
              }),
              child: GestureDetector(
                onTap: widget.onOpened,
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Stack(
                        children: [
                          MiniPathPreview(
                            path: widget.path,
                            fieldImage: widget.fieldImage,
                          ),
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _hovering ? 1.0 : 0.0,
                              curve: Curves.easeInOut,
                              duration: const Duration(milliseconds: 200),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                child: Container(),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: AnimatedScale(
                                scale: _hovering ? 1.0 : 0.0,
                                curve: Curves.easeInOut,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.edit,
                                  color: colorScheme.onSurface,
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
