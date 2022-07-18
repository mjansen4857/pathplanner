import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:process_run/shell.dart';

class PPLibUpdateCard extends StatefulWidget {
  final Directory projectDir;

  PPLibUpdateCard({required this.projectDir, super.key});

  @override
  State<PPLibUpdateCard> createState() => _PPLibUpdateCardState();
}

class _PPLibUpdateCardState extends State<PPLibUpdateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _updateController;
  late Animation<Offset> _offsetAnimation;
  bool _visibile = false;
  late File _vendorDepFile;
  String? _remoteFileContent;
  final String _jsonURL =
      'https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib.json';

  @override
  void initState() {
    super.initState();

    _updateController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 400));
    _offsetAnimation = Tween<Offset>(begin: Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _updateController,
      curve: Curves.ease,
    ));

    _vendorDepFile =
        File(join(widget.projectDir.path, 'vendordeps', 'PathplannerLib.json'));

    if (_vendorDepFile.existsSync()) {
      _vendorDepFile.readAsString().then((local) {
        Map<String, dynamic> localJson = jsonDecode(local);

        try {
          http.read(Uri.parse(_jsonURL)).then((remote) {
            Map<String, dynamic> remoteJson = jsonDecode(remote);

            String localVersion = localJson['version'];
            String remoteVersion = remoteJson['version'];

            print(
                'Current PPLib Version: $localVersion, Latest Release: $remoteVersion');

            // Assume that if the versions are different, remote is newest
            if (localVersion != remoteVersion) {
              setState(() {
                _remoteFileContent = remote;
                _visibile = true;
                _updateController.forward();
              });
            }
          });
        } catch (e) {
          // Can't get file. Probably not connected to internet
        }
      });
    }
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
              padding: EdgeInsets.all(10.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PathPlannerLib update available!',
                    style:
                        TextStyle(fontSize: 18, color: colorScheme.onSurface),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      primary: colorScheme.primaryContainer,
                      onPrimary: colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () async {
                      if (_remoteFileContent != null) {
                        await _vendorDepFile.writeAsString(_remoteFileContent!,
                            flush: true);

                        setState(() {
                          _visibile = false;
                        });

                        Shell shell = Shell().cd(widget.projectDir.path);
                        _showSnackbar(context, 'Building robot code...',
                            duration: Duration(minutes: 10));
                        try {
                          String gradlew =
                              Platform.isWindows ? 'gradlew' : './gradlew';
                          ProcessResult result = await shell
                              .runExecutableArguments(gradlew, ['build']);
                          ScaffoldMessenger.of(context).removeCurrentSnackBar();
                          if (result.exitCode == 0) {
                            _showSnackbar(
                                context, 'Successfully built robot code.',
                                textColor: colorScheme.primary);
                          } else {
                            _showSnackbar(context,
                                'Failed to build robot code. Please build through Visual Studio Code.',
                                textColor: colorScheme.error);
                          }
                        } on ShellException catch (_) {
                          ScaffoldMessenger.of(context).removeCurrentSnackBar();
                          _showSnackbar(context,
                              'Failed to build robot code. Please build through Visual Studio Code.',
                              textColor: colorScheme.error);
                        }
                      }
                    },
                    child: Text('Update'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      primary: colorScheme.surfaceVariant,
                      onPrimary: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() {
                        _visibile = false;
                      });
                    },
                    child: Text('Dismiss'),
                  ),
                ],
              ),
            ),
          ),
        ),
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
