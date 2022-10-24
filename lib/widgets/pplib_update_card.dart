import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:pathplanner/services/log.dart';
import 'package:process_run/shell.dart';
import 'package:version/version.dart';

class PPLibUpdateCard extends StatefulWidget {
  final Directory projectDir;

  const PPLibUpdateCard({required this.projectDir, super.key});

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

    _updateController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
            .animate(CurvedAnimation(
      parent: _updateController,
      curve: Curves.ease,
    ));

    _vendorDepFile =
        File(join(widget.projectDir.path, 'vendordeps', 'PathplannerLib.json'));

    if (_vendorDepFile.existsSync()) {
      _vendorDepFile.readAsString().then((local) async {
        Map<String, dynamic> localJson = jsonDecode(local);

        try {
          String remote = await http.read(Uri.parse(_jsonURL));
          Map<String, dynamic> remoteJson = jsonDecode(remote);

          String localVersion = localJson['version'];
          String remoteVersion = remoteJson['version'];

          Log.verbose(
              'Current PPLib Version: $localVersion, Latest Release: $remoteVersion');

          if (Version.parse(remoteVersion) > Version.parse(localVersion)) {
            setState(() {
              _remoteFileContent = remote;
              _visibile = true;
              _updateController.forward();
            });
          }
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
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () async {
                      if (_remoteFileContent != null) {
                        await _vendorDepFile.writeAsString(_remoteFileContent!,
                            flush: true);

                        setState(() {
                          _visibile = false;
                        });

                        Shell shell = Shell().cd(widget.projectDir.path);

                        if (!mounted) return;
                        _showSnackbar(context, 'Building robot code...',
                            duration: const Duration(minutes: 10));

                        try {
                          String gradlew =
                              Platform.isWindows ? 'gradlew' : './gradlew';
                          ProcessResult result = await shell
                              .runExecutableArguments(gradlew, ['build']);

                          if (!mounted) return;
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
                    child: const Text('Update'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.surfaceVariant,
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
