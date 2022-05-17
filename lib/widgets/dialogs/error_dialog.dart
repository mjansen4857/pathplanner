import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ErrorDialog extends StatefulWidget {
  final FlutterErrorDetails errorDetails;

  ErrorDialog({required this.errorDetails, super.key});

  @override
  State<ErrorDialog> createState() => _ErrorDialogState();
}

class _ErrorDialogState extends State<ErrorDialog> {
  String? _logFilePath;

  @override
  void initState() {
    super.initState();

    getApplicationSupportDirectory().then((supportDir) {
      setState(() {
        _logFilePath = join(supportDir.path, 'log.txt');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('PathPlanner encountered an error'),
      content: Container(
        constraints: BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SelectableText(
                widget.errorDetails.exception.toString(),
                style: TextStyle(color: Colors.red),
              ),
            ),
            SizedBox(height: 18),
            Flexible(
              child: SelectableText.rich(
                TextSpan(
                  text:
                      'If you are going to report this error, please include the steps to reproduce and the log file located at: ',
                  children: [
                    TextSpan(
                      text: _logFilePath,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            exit(1);
          },
          child: Text('Exit'),
        ),
      ],
    );
  }
}
