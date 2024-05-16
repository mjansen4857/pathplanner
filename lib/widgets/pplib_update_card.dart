import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/services/update_checker.dart';

class PPLibUpdateCard extends StatefulWidget {
  final Directory projectDir;
  final FileSystem fs;
  final UpdateChecker updateChecker;

  const PPLibUpdateCard({
    required this.projectDir,
    required this.fs,
    required this.updateChecker,
    super.key,
  });

  @override
  State<PPLibUpdateCard> createState() => _PPLibUpdateCardState();
}

class _PPLibUpdateCardState extends State<PPLibUpdateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _updateController;
  late Animation<Offset> _offsetAnimation;
  bool _visibile = false;

  @override
  void initState() {
    super.initState();

    _updateController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
            .animate(CurvedAnimation(
      parent: _updateController,
      curve: Curves.ease,
    ));

    widget.updateChecker
        .isPPLibUpdateAvailable(projectDir: widget.projectDir, fs: widget.fs)
        .then((value) {
      if (value) {
        setState(() {
          _visibile = true;
          _updateController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Visibility(
      visible: _visibile,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PathPlannerLib update available!',
                    style:
                        TextStyle(fontSize: 18, color: colorScheme.onSurface),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() {
                        _visibile = false;
                      });
                    },
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
