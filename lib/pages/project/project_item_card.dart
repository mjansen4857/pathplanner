import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pathplanner/pages/editor_page.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/mini_path_preview.dart';

class ProjectItemCard extends StatefulWidget {
  final String name;
  final FieldImage fieldImage;
  final PathPlannerPath path;
  final VoidCallback onOpened;

  const ProjectItemCard({
    super.key,
    required this.name,
    required this.fieldImage,
    required this.path,
    required this.onOpened,
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
                        onPressed: () {},
                        icon: const Icon(Icons.copy),
                      ),
                    ),
                  ),
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 24),
                  ),
                  Tooltip(
                    message: 'Delete',
                    waitDuration: const Duration(seconds: 1),
                    child: FittedBox(
                      child: IconButton(
                        onPressed: () {},
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
