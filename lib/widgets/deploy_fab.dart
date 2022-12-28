import 'dart:io';

import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';

class DeployFAB extends StatelessWidget {
  final Directory? projectDir;

  const DeployFAB({required this.projectDir, super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Deploy Robot Code',
      waitDuration: const Duration(milliseconds: 500),
      child: FloatingActionButton.extended(
        icon: const Icon(Icons.send_rounded),
        label: const Text('Deploy'),
        onPressed: ([bool mounted = true]) async {
          Shell shell = Shell().cd(projectDir!.path);
          _showSnackbar(context, 'Deploying robot code...',
              duration: const Duration(minutes: 10));

          String gradlew = Platform.isWindows ? 'gradlew' : './gradlew';
          shell.runExecutableArguments(gradlew, ['deploy']).then((result) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            if (result.exitCode == 0) {
              _showSnackbar(context, 'Successfully deployed.',
                  textColor: colorScheme.primary);
            } else {
              _showSnackbar(context, 'Failed to deploy.',
                  textColor: colorScheme.error);
            }
          }).catchError((err, stackTrace) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            _showSnackbar(context, 'Failed to deploy.',
                textColor: colorScheme.error);
          });
        },
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message,
      {Duration? duration, Color textColor = Colors.white}) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 16),
      ),
      duration: duration ?? const Duration(milliseconds: 4000),
      backgroundColor: colorScheme.surfaceVariant,
    ));
  }
}
