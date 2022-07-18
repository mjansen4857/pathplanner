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
      waitDuration: Duration(milliseconds: 500),
      child: FloatingActionButton.extended(
        icon: Icon(Icons.send_rounded),
        label: Text('Deploy'),
        onPressed: () async {
          Shell shell = Shell().cd(projectDir!.path);
          _showSnackbar(context, 'Deploying robot code...',
              duration: Duration(minutes: 10));
          try {
            String gradlew = Platform.isWindows ? 'gradlew' : './gradlew';
            ProcessResult result =
                await shell.runExecutableArguments(gradlew, ['deploy']);
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            if (result.exitCode == 0) {
              _showSnackbar(context, 'Successfully deployed.',
                  textColor: colorScheme.primary);
            } else {
              _showSnackbar(context, 'Failed to deploy.',
                  textColor: colorScheme.error);
            }
          } on ShellException catch (_) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            _showSnackbar(context, 'Failed to deploy.',
                textColor: colorScheme.error);
          }
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
      duration: duration ?? Duration(milliseconds: 4000),
      backgroundColor: colorScheme.surfaceVariant,
    ));
  }
}
