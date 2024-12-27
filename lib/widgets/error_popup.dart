import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ErrorPopup extends StatelessWidget {
  final SharedPreferences prefs;
  final Object error;
  final StackTrace stackTrace;

  late final Color _teamColor;

  static const String _reportURL =
      'https://github.com/mjansen4857/pathplanner/issues/new?assignees=&labels=bug&projects=&template=bug_report.md&title=';

  ErrorPopup({
    super.key,
    required this.prefs,
    required this.error,
    required this.stackTrace,
  }) {
    _teamColor = Color(prefs.getInt(PrefsKeys.teamColor) ?? Defaults.teamColor);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Error',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _teamColor,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Uncaught Error',
                style: TextStyle(fontSize: 32),
              ),
              const Divider(),
              const SizedBox(height: 24),
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    '$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Builder(builder: (context) {
                ColorScheme colorScheme = Theme.of(context).colorScheme;
                return ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Stack Trace'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    surfaceTintColor: colorScheme.surfaceTint,
                    foregroundColor: colorScheme.primary,
                  ),
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: stackTrace.toString())),
                );
              }),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                ColorScheme colorScheme = Theme.of(context).colorScheme;
                return ElevatedButton.icon(
                  icon: const Icon(Icons.report),
                  label: const Text('Report Issue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    surfaceTintColor: colorScheme.surfaceTint,
                    foregroundColor: colorScheme.error,
                  ),
                  onPressed: () async {
                    Uri url = Uri.parse(_reportURL);
                    if (await canLaunchUrl(url)) {
                      launchUrl(url);
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
