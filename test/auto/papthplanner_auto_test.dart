import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';

void main() {
  group('Basic functions', () {
    test('equals/hashCode', () {
      var fs = MemoryFileSystem();

      PathPlannerAuto auto1 = PathPlannerAuto(
        name: 'test',
        autoDir: '/autos',
        fs: fs,
        startingPose: Pose2d(),
        sequence:
            SequentialCommandGroup(commands: [WaitCommand(waitTime: 1.0)]),
        folder: null,
        choreoAuto: false,
      );
      PathPlannerAuto auto2 = PathPlannerAuto(
        name: 'test',
        autoDir: '/autos',
        fs: fs,
        startingPose: Pose2d(),
        sequence:
            SequentialCommandGroup(commands: [WaitCommand(waitTime: 1.0)]),
        folder: null,
        choreoAuto: false,
      );
      PathPlannerAuto auto3 = PathPlannerAuto(
        name: 'test2',
        autoDir: '/autos',
        fs: fs,
        sequence: SequentialCommandGroup(commands: []),
        startingPose: null,
        folder: null,
        choreoAuto: false,
      );

      expect(auto2, auto1);
      expect(auto3, isNot(auto1));

      expect(auto3.hashCode, isNot(auto1.hashCode));
    });

    test('toJson/fromJson interoperability', () {
      var fs = MemoryFileSystem();

      PathPlannerAuto auto = PathPlannerAuto(
        name: 'test',
        autoDir: '/autos',
        fs: fs,
        startingPose: Pose2d(),
        sequence:
            SequentialCommandGroup(commands: [WaitCommand(waitTime: 1.0)]),
        folder: null,
        choreoAuto: false,
      );

      Map<String, dynamic> json = auto.toJson();
      PathPlannerAuto fromJson =
          PathPlannerAuto.fromJsonV1(json, auto.name, '/autos', fs);

      expect(fromJson, auto);
    });

    test('duplication', () {
      var fs = MemoryFileSystem();

      PathPlannerAuto auto = PathPlannerAuto(
        name: 'test',
        autoDir: '/autos',
        fs: fs,
        sequence:
            SequentialCommandGroup(commands: [WaitCommand(waitTime: 1.0)]),
        folder: null,
        startingPose: null,
        choreoAuto: false,
      );
      PathPlannerAuto cloned = auto.duplicate(auto.name);

      expect(cloned, auto);

      auto.sequence.commands.clear();

      expect(auto, isNot(cloned));
    });
  });

  test('getAllPathNames', () {
    var fs = MemoryFileSystem();

    PathPlannerAuto auto = PathPlannerAuto(
      name: 'test',
      autoDir: '/autos',
      fs: fs,
      folder: null,
      startingPose: null,
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          SequentialCommandGroup(
            commands: [
              PathCommand(pathName: 'path2'),
            ],
          ),
          PathCommand(pathName: 'path3'),
        ],
      ),
      choreoAuto: false,
    );

    expect(
        listEquals(auto.getAllPathNames(), ['path1', 'path2', 'path3']), true);
  });

  test('hasEmptyPathCommands', () {
    var fs = MemoryFileSystem();

    PathPlannerAuto auto1 = PathPlannerAuto(
      name: 'test',
      autoDir: '/autos',
      fs: fs,
      folder: null,
      startingPose: null,
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          SequentialCommandGroup(
            commands: [
              PathCommand(pathName: 'path2'),
            ],
          ),
          PathCommand(pathName: 'path3'),
        ],
      ),
      choreoAuto: false,
    );

    expect(auto1.hasEmptyPathCommands(), false);

    PathPlannerAuto auto2 = PathPlannerAuto(
      name: 'test',
      autoDir: '/autos',
      fs: fs,
      folder: null,
      startingPose: null,
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          SequentialCommandGroup(
            commands: [
              PathCommand(),
            ],
          ),
          PathCommand(pathName: 'path3'),
        ],
      ),
      choreoAuto: false,
    );

    expect(auto2.hasEmptyPathCommands(), true);
  });

  test('handleMissingPaths', () {
    var fs = MemoryFileSystem();

    PathPlannerAuto auto = PathPlannerAuto(
      name: 'test',
      autoDir: '/autos',
      fs: fs,
      folder: null,
      startingPose: null,
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          SequentialCommandGroup(
            commands: [
              PathCommand(pathName: 'path2'),
            ],
          ),
          PathCommand(pathName: 'path3'),
        ],
      ),
      choreoAuto: false,
    );

    auto.handleMissingPaths(['path1', 'path3']);

    List<String> pathNames = auto.getAllPathNames();

    expect(pathNames.length, 2);
    expect(pathNames.contains('path1'), true);
    expect(pathNames.contains('path2'), false);
    expect(pathNames.contains('path3'), true);
  });

  test('hasEmptyNamedCommand', () {
    var fs = MemoryFileSystem();

    PathPlannerAuto auto = PathPlannerAuto(
      name: 'test',
      autoDir: '/autos',
      fs: fs,
      folder: null,
      startingPose: null,
      sequence: SequentialCommandGroup(
        commands: [
          SequentialCommandGroup(
            commands: [
              NamedCommand(),
            ],
          ),
        ],
      ),
      choreoAuto: false,
    );

    expect(auto.hasEmptyNamedCommand(), true);
  });

  test('updatePathName', () {
    var fs = MemoryFileSystem();

    Directory autoDir = fs.directory('/autos');
    fs.file(join(autoDir.path, 'test.auto')).createSync(recursive: true);

    PathPlannerAuto auto = PathPlannerAuto(
      name: 'test',
      autoDir: '/autos',
      fs: fs,
      folder: null,
      startingPose: null,
      sequence: SequentialCommandGroup(
        commands: [
          PathCommand(pathName: 'path1'),
          SequentialCommandGroup(
            commands: [
              PathCommand(pathName: 'path2'),
            ],
          ),
          PathCommand(pathName: 'path3'),
        ],
      ),
      choreoAuto: false,
    );

    auto.updatePathName('path1', 'updated1');

    expect((auto.sequence.commands[0] as PathCommand).pathName, 'updated1');
    expect(
        ((auto.sequence.commands[1] as SequentialCommandGroup).commands[0]
                as PathCommand)
            .pathName,
        'path2');
    expect((auto.sequence.commands[2] as PathCommand).pathName, 'path3');

    auto.updatePathName('path2', 'updated2');

    expect((auto.sequence.commands[0] as PathCommand).pathName, 'updated1');
    expect(
        ((auto.sequence.commands[1] as SequentialCommandGroup).commands[0]
                as PathCommand)
            .pathName,
        'updated2');
    expect((auto.sequence.commands[2] as PathCommand).pathName, 'path3');
  });

  group('file management', () {
    late MemoryFileSystem fs;
    final String autosPath = Platform.isWindows ? 'C:\\autos' : '/autos';

    setUp(() => fs = MemoryFileSystem(
        style: Platform.isWindows
            ? FileSystemStyle.windows
            : FileSystemStyle.posix));

    test('rename', () {
      Directory autoDir = fs.directory(autosPath);
      fs.file(join(autoDir.path, 'test.auto')).createSync(recursive: true);

      PathPlannerAuto auto = PathPlannerAuto.defaultAuto(
          name: 'test', autoDir: autoDir.path, fs: fs);

      auto.rename('renamed');

      expect(auto.name, 'renamed');
      expect(fs.file(join(autoDir.path, 'test.auto')).existsSync(), false);
      expect(fs.file(join(autoDir.path, 'renamed.auto')).existsSync(), true);
    });

    test('delete', () {
      Directory autoDir = fs.directory(autosPath);
      fs.file(join(autoDir.path, 'test.auto')).createSync(recursive: true);

      PathPlannerAuto auto = PathPlannerAuto.defaultAuto(
          name: 'test', autoDir: autoDir.path, fs: fs);

      auto.delete();

      expect(fs.file(join(autoDir.path, 'test.auto')).existsSync(), false);
    });

    test('load autos in dir', () async {
      Directory autoDir = fs.directory(autosPath);
      autoDir.createSync(recursive: true);

      PathPlannerAuto auto1 = PathPlannerAuto.defaultAuto(
          name: 'test1', autoDir: autoDir.path, fs: fs);
      PathPlannerAuto auto2 = PathPlannerAuto.defaultAuto(
          name: 'test2', autoDir: autoDir.path, fs: fs);
      auto2.sequence.commands.add(WaitCommand(waitTime: 0.5));

      fs
          .file(join(autoDir.path, 'test1.auto'))
          .writeAsStringSync(jsonEncode(auto1.toJson()));
      fs
          .file(join(autoDir.path, 'test2.auto'))
          .writeAsStringSync(jsonEncode(auto2.toJson()));

      List<PathPlannerAuto> loaded =
          await PathPlannerAuto.loadAllAutosInDir(autoDir.path, fs);

      expect(loaded.length, 2);

      // Sort autos by name so they should be in the order: auto1, auto2
      loaded.sort((a, b) => a.name.compareTo(b.name));

      expect(loaded[0], auto1);
      expect(loaded[1], auto2);
    });

    test('save', () {
      Directory autoDir = fs.directory(autosPath);
      autoDir.createSync(recursive: true);

      PathPlannerAuto auto = PathPlannerAuto.defaultAuto(
          name: 'test', autoDir: autoDir.path, fs: fs);
      auto.sequence.commands.add(WaitCommand(waitTime: 1.0));

      auto.saveFile();

      File autoFile = fs.file(join(autoDir.path, 'test.auto'));
      expect(autoFile.existsSync(), true);

      String fileContent = autoFile.readAsStringSync();
      Map<String, dynamic> fileJson = jsonDecode(fileContent);
      expect(
          const DeepCollectionEquality().equals(fileJson, auto.toJson()), true);
    });
  });
}
