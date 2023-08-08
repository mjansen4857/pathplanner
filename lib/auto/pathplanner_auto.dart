import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/services/log.dart';

class PathPlannerAuto {
  String name;
  Pose2d? startingPose;
  SequentialCommandGroup sequence;

  FileSystem fs;
  String autoDir;

  PathPlannerAuto({
    required this.name,
    required this.sequence,
    required this.autoDir,
    required this.fs,
    this.startingPose,
  });

  PathPlannerAuto.defaultAuto({
    this.name = 'New Auto',
    required this.autoDir,
    required this.fs,
  }) : sequence = SequentialCommandGroup(commands: []);

  PathPlannerAuto duplicate(String newName) {
    return PathPlannerAuto(
      name: newName,
      sequence: sequence.clone() as SequentialCommandGroup,
      autoDir: autoDir,
      fs: fs,
      startingPose: startingPose,
    );
  }

  PathPlannerAuto.fromJsonV1(
      Map<String, dynamic> json, String name, String autosDir, FileSystem fs)
      : this(
          autoDir: autosDir,
          fs: fs,
          name: name,
          startingPose: json['startingPose'] == null
              ? null
              : Pose2d.fromJson(json['startingPose']),
          sequence:
              Command.fromJson(json['command'] ?? {}) as SequentialCommandGroup,
        );

  Map<String, dynamic> toJson() {
    return {
      'version': 1.0,
      'startingPose': startingPose?.toJson(),
      'command': sequence.toJson(),
    };
  }

  static Future<List<PathPlannerAuto>> loadAllAutosInDir(
      String autosDir, FileSystem fs) async {
    List<PathPlannerAuto> autos = [];

    List<FileSystemEntity> files = fs.directory(autosDir).listSync();
    for (FileSystemEntity e in files) {
      if (e.path.endsWith('.auto')) {
        String jsonStr = await fs.file(e.path).readAsString();
        try {
          Map<String, dynamic> json = jsonDecode(jsonStr);
          String autoName = basenameWithoutExtension(e.path);

          if (json['version'] == 1.0) {
            autos.add(PathPlannerAuto.fromJsonV1(json, autoName, autosDir, fs));
          } else {
            Log.error('Unknown auto version');
          }
        } catch (ex, stack) {
          Log.error('Failed to load auto', ex, stack);
        }
      }
    }
    return autos;
  }

  void rename(String name) {
    File autoFile = fs.file(join(autoDir, '${this.name}.auto'));

    if (autoFile.existsSync()) {
      autoFile.rename(join(autoDir, '$name.auto'));
    }
    this.name = name;
  }

  void delete() {
    File autoFile = fs.file(join(autoDir, '$name.auto'));

    if (autoFile.existsSync()) {
      autoFile.delete();
    }
  }

  void saveFile() {
    try {
      File autoFile = fs.file(join(autoDir, '$name.auto'));
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      autoFile.writeAsString(encoder.convert(this));
      Log.debug('Saved "$name.auto"');
    } catch (ex, stack) {
      Log.error('Failed to save auto', ex, stack);
    }
  }

  void updatePathName(String oldPathName, String newPathName) {
    _updatePathNameInCommands(sequence.commands, oldPathName, newPathName);
    saveFile();
  }

  void _updatePathNameInCommands(
      List<Command> commands, String oldPathName, String newPathName) {
    for (Command cmd in commands) {
      if (cmd is PathCommand && cmd.pathName == oldPathName) {
        cmd.pathName = newPathName;
      } else if (cmd is CommandGroup) {
        _updatePathNameInCommands(cmd.commands, oldPathName, newPathName);
      }
    }
  }

  List<String> getAllPathNames() {
    return _getPathNamesInCommands(sequence.commands);
  }

  List<String> _getPathNamesInCommands(List<Command> commands) {
    List<String> names = [];
    for (Command cmd in commands) {
      if (cmd is PathCommand && cmd.pathName != null) {
        names.add(cmd.pathName!);
      } else if (cmd is CommandGroup) {
        names.addAll(_getPathNamesInCommands(cmd.commands));
      }
    }
    return names;
  }

  @override
  bool operator ==(Object other) =>
      other is PathPlannerAuto &&
      other.runtimeType == runtimeType &&
      other.name == name &&
      other.startingPose == startingPose &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(name, startingPose, sequence);
}
