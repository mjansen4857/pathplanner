import 'package:flutter/material.dart';
import 'package:pathplanner/coderunner/api/deploy_files_client.dart';
import 'package:pathplanner/coderunner/config.dart';
import 'package:pathplanner/coderunner/fs/coderunner_file_system.dart';
import 'package:pathplanner/coderunner/fs/sync_queue.dart';
import 'package:pathplanner/coderunner/services/noop_telemetry.dart';
import 'package:pathplanner/coderunner/services/noop_update_checker.dart';
import 'package:pathplanner/coderunner/web_mode.dart';
import 'package:pathplanner/pages/home_page.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

/// Root widget of the CodeRunner web build. Mirrors the PathPlanner
/// widget in lib/main.dart (theme + HomePage wiring) with CodeRunner
/// implementations injected, plus hydration states and a save indicator.
class CodeRunnerApp extends StatefulWidget {
  final CodeRunnerConfig config;
  final String appVersion;
  final DeployFilesClient? client;

  const CodeRunnerApp({
    required this.config,
    required this.appVersion,
    this.client,
    super.key,
  });

  @override
  State<CodeRunnerApp> createState() => _CodeRunnerAppState();
}

class _CodeRunnerAppState extends State<CodeRunnerApp> {
  late DeployFilesClient _client;
  late SyncQueue _queue;
  late Future<_BootResult> _boot;
  Color _teamColor = const Color(Defaults.teamColor);

  @override
  void initState() {
    super.initState();
    CodeRunnerWebMode.enabled = true;
    _client =
        widget.client ?? DeployFilesClient(baseUrl: widget.config.apiBase);
    _boot = _hydrate();
  }

  Future<_BootResult> _hydrate() async {
    _queue = SyncQueue(client: _client);
    final fs =
        await CodeRunnerFileSystem.hydrate(client: _client, queue: _queue);
    final prefs = await SharedPreferences.getInstance();
    // Pin the project so HomePage never shows the welcome/picker flow.
    await prefs.setString(
        PrefsKeys.currentProjectDir, CodeRunnerFileSystem.projectRoot);
    return _BootResult(fs: fs, prefs: prefs);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PathPlanner',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _teamColor,
        brightness: Brightness.dark,
      ),
      home: FutureBuilder<_BootResult>(
        future: _boot,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError(context, snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final boot = snapshot.data!;
          _teamColor = Color(
              boot.prefs.getInt(PrefsKeys.teamColor) ?? Defaults.teamColor);
          return Stack(
            children: [
              HomePage(
                appVersion: widget.appVersion,
                prefs: boot.prefs,
                fs: boot.fs,
                undoStack: ChangeStack(),
                telemetry: CodeRunnerNoopTelemetry(),
                updateChecker: CodeRunnerNoopUpdateChecker(),
                onTeamColorChanged: (color) {
                  setState(() {
                    _teamColor = color;
                    boot.prefs.setInt(PrefsKeys.teamColor, color.toARGB32());
                  });
                },
              ),
              _SaveIndicator(state: _queue.state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Failed to load workspace files: $error',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {
                _boot = _hydrate();
              }),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootResult {
  final CodeRunnerFileSystem fs;
  final SharedPreferences prefs;

  const _BootResult({required this.fs, required this.prefs});
}

/// Small floating chip showing sync state: hidden when saved, spinner
/// while saving, warning while the queue is retrying a failed request.
class _SaveIndicator extends StatelessWidget {
  final ValueNotifier<SaveState> state;

  const _SaveIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: ValueListenableBuilder<SaveState>(
        valueListenable: state,
        builder: (context, value, _) {
          return switch (value) {
            SaveState.saved => const SizedBox.shrink(),
            SaveState.saving => const Chip(
                avatar: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: Text('Saving…'),
              ),
            SaveState.error => const Chip(
                avatar: Icon(Icons.warning_amber_rounded, size: 16),
                label: Text('Changes not saved — retrying'),
              ),
          };
        },
      ),
    );
  }
}
