import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/services/log.dart';

class PathPlannerAuto {
  String name;
  SequentialCommandGroup sequence;
  bool choreoAuto;

  String? folder;

  FileSystem fs;
  String autoDir;

  // Stuff used for UI
  DateTime lastModified = DateTime.now().toUtc();

  PathPlannerAuto({
    required this.name,
    required this.sequence,
    required this.autoDir,
    required this.fs,
    required this.folder,
    required this.choreoAuto,
  }) {
    _addNamedCommandsToSet(sequence.commands);
  }

  PathPlannerAuto.defaultAuto({
    this.name = 'New Auto',
    required this.autoDir,
    required this.fs,
    this.folder,
    this.choreoAuto = false,
  }) : sequence = SequentialCommandGroup(commands: []);

  PathPlannerAuto duplicate(String newName) {
    return PathPlannerAuto(
      name: newName,
      sequence: sequence.clone() as SequentialCommandGroup,
      autoDir: autoDir,
      fs: fs,
      folder: folder,
      choreoAuto: choreoAuto,
    );
  }

  PathPlannerAuto.fromJsonV1(
      Map<String, dynamic> json, String name, String autosDir, FileSystem fs)
      : this(
          autoDir: autosDir,
          fs: fs,
          name: name,
          sequence:
              Command.fromJson(json['command'] ?? {}) as SequentialCommandGroup,
          folder: json['folder'],
          choreoAuto: json['choreoAuto'] ?? false,
        );

  Map<String, dynamic> toJson() {
    return {
      'version': 1.0,
      'command': sequence.toJson(),
      'folder': folder,
      'choreoAuto': choreoAuto,
    };
  }

  static Future<List<PathPlannerAuto>> loadAllAutosInDir(
      String autosDir, FileSystem fs) async {
    List<PathPlannerAuto> autos = [];

    List<FileSystemEntity> files = fs.directory(autosDir).listSync();
    for (FileSystemEntity e in files) {
      if (e.path.endsWith('.auto')) {
        final file = fs.file(e.path);
        String jsonStr = await file.readAsString();
        try {
          Map<String, dynamic> json = jsonDecode(jsonStr);
          String autoName = basenameWithoutExtension(e.path);

          if (json['version'] == 1.0) {
            PathPlannerAuto auto =
                PathPlannerAuto.fromJsonV1(json, autoName, autosDir, fs);
            auto.lastModified = (await file.lastModified()).toUtc();

            autos.add(auto);
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
    lastModified = DateTime.now().toUtc();
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
      lastModified = DateTime.now().toUtc();
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

  void _addNamedCommandsToSet(List<Command> commands) {
    for (Command cmd in commands) {
      if (cmd is NamedCommand) {
        if (cmd.name != null) {
          Command.named.add(cmd.name!);
          continue;
        }
      }

      if (cmd is CommandGroup) {
        _addNamedCommandsToSet(cmd.commands);
      }
    }
  }

  List<String> getAllPathNames() {
    return _getPathNamesInCommands(sequence.commands);
  }

  bool hasEmptyPathCommands() {
    return _hasEmptyPathCommands(sequence.commands);
  }

  bool _hasEmptyPathCommands(List<Command> commands) {
    for (Command cmd in commands) {
      if (cmd is PathCommand && cmd.pathName == null) {
        return true;
      } else if (cmd is CommandGroup) {
        bool hasEmpty = _hasEmptyPathCommands(cmd.commands);
        if (hasEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  bool hasEmptyNamedCommand() {
    return _hasEmptyNamedCommand(sequence.commands);
  }

  bool _hasEmptyNamedCommand(List<Command> commands) {
    for (Command cmd in commands) {
      if (cmd is NamedCommand && cmd.name == null) {
        return true;
      } else if (cmd is CommandGroup) {
        bool hasEmpty = _hasEmptyNamedCommand(cmd.commands);
        if (hasEmpty) {
          return true;
        }
      }
    }
    return false;
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

  void handleMissingPaths(List<String> pathNames) {
    return _handleMissingPaths(sequence.commands, pathNames);
  }

  void _handleMissingPaths(List<Command> commands, List<String> pathNames) {
    for (Command cmd in commands) {
      if (cmd is PathCommand && !pathNames.contains(cmd.pathName)) {
        cmd.pathName = null;
      } else if (cmd is CommandGroup) {
        _handleMissingPaths(cmd.commands, pathNames);
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PathPlannerAuto &&
      other.runtimeType == runtimeType &&
      other.name == name &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(name, sequence);
}
