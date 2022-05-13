import 'dart:io';

import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';

class DeployFAB extends StatelessWidget {
  final Directory projectDir;

  const DeployFAB({required this.projectDir, super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Deploy Robot Code',
      waitDuration: Duration(milliseconds: 500),
      child: FloatingActionButton(
        child: Icon(Icons.send_rounded),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.green,
        onPressed: () async {
          Shell shell = Shell().cd(projectDir.path);
          _showSnackbar(context, 'Deploying robot code...',
              duration: Duration(minutes: 5));
          try {
            String gradlew = Platform.isWindows ? 'gradlew' : './gradlew';
            ProcessResult result =
                await shell.runExecutableArguments(gradlew, ['deploy']);
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            if (result.exitCode == 0) {
              _showSnackbar(context, 'Successfully deployed.',
                  textColor: Colors.green);
            } else {
              _showSnackbar(context, 'Failed to deploy.',
                  textColor: Colors.red);
            }
          } on ShellException catch (_) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            _showSnackbar(context, 'Failed to deploy.', textColor: Colors.red);
          }
        },
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message,
      {Duration? duration, Color textColor = Colors.white}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 16),
      ),
      duration: duration ?? Duration(milliseconds: 4000),
      backgroundColor: Colors.grey[900],
    ));
  }
}
