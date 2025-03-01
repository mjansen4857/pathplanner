import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/mini_path_preview.dart';
import 'package:pathplanner/widgets/renamable_title.dart';

class ProjectItemCard extends StatefulWidget {
  final String name;
  final FieldImage fieldImage;
  final List<List<Translation2d>> paths;
  final VoidCallback onOpened;
  final VoidCallback? onReverse;
  final VoidCallback? onReverseH;
  final VoidCallback? onDuplicated;
  final VoidCallback? onDeleted;
  final ValueChanged<String>? onRenamed;
  final bool compact;
  final String? warningMessage;
  final bool showOptions;
  final bool choreoItem;

  const ProjectItemCard({
    super.key,
    required this.name,
    required this.fieldImage,
    required this.paths,
    required this.onOpened,
    this.onReverse,
    this.onReverseH,
    this.onDuplicated,
    this.onDeleted,
    this.onRenamed,
    this.compact = false,
    this.warningMessage,
    this.showOptions = true,
    this.choreoItem = false,
  });

  @override
  State<ProjectItemCard> createState() => _ProjectItemCardState();
}

class _ProjectItemCardState extends State<ProjectItemCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          color: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  height: 38,
                  color: Colors.white.withAlpha(15),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: RenamableTitle(
                            title: widget.name,
                            textStyle: const TextStyle(fontSize: 28),
                            onRename: widget.onRenamed,
                          ),
                        ),
                      ),
                      if (widget.showOptions)
                        FittedBox(
                          child: PopupMenuButton<String>(
                            tooltip: '',
                            onSelected: (value) {
                              if (value == 'reverse') {
                                widget.onReverse?.call();
                              } else if (value == 'reverseH') {
                                widget.onReverseH?.call();
                              } else if (value == 'duplicate') {
                                widget.onDuplicated?.call();
                              } else if (value == 'delete') {
                                _showDeleteDialog();
                              }
                            },
                            itemBuilder: (_) {
                              return const [
                                PopupMenuItem(
                                  value: 'reverse',
                                  child: Row(
                                    children: [
                                      Icon(Icons.compare_arrows),
                                      SizedBox(width: 12),
                                      Text('Reverse'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'reverseH',
                                  child: Row(
                                    children: [
                                      Icon(Icons.compare_arrows),
                                      SizedBox(width: 12),
                                      Text('Reverse H'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'duplicate',
                                  child: Row(
                                    children: [
                                      Icon(Icons.copy),
                                      SizedBox(width: 12),
                                      Text('Duplicate'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_forever),
                                      SizedBox(width: 12),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ConditionalWidget(
                condition: widget.compact,
                trueChild: Expanded(
                  flex: 5,
                  child: InkWell(
                    onTap: widget.onOpened,
                    hoverColor: Colors.white.withAlpha(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                falseChild: Expanded(
                  flex: 16,
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
                                MiniPathsPreview(
                                  paths: widget.paths,
                                  fieldImage: widget.fieldImage,
                                ),
                                Positioned.fill(
                                  child: AnimatedOpacity(
                                    opacity: _hovering ? 1.0 : 0.0,
                                    curve: Curves.easeInOut,
                                    duration: const Duration(milliseconds: 200),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
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
              ),
            ],
          ),
        ),
        if (widget.warningMessage != null)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: widget.compact ? const EdgeInsets.all(8.0) : const EdgeInsets.all(12.0),
              child: Tooltip(
                message: widget.warningMessage,
                child: FittedBox(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: widget.compact ? 32 : 48,
                    color: Colors.orange[300]!,
                    shadows: widget.compact
                        ? null
                        : const [
                            Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 4,
                            )
                          ],
                  ),
                ),
              ),
            ),
          ),
        if (widget.choreoItem)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'images/choreo.png',
                filterQuality: FilterQuality.medium,
                width: widget.compact ? 32 : 40,
              ),
            ),
          ),
      ],
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        ColorScheme colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: const Text('Delete File'),
          content: Text(
              'Are you sure you want to delete the file: ${widget.name}? This cannot be undone.\n\nIf this is a path, any autos using it will have their reference to it removed.'),
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
                widget.onDeleted?.call();
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }
}
