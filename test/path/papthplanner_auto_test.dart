import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/path/pathplanner_auto.dart';

void main() {
  group('Basic functions', () {
    test('equals/hashCode', () {
      PathPlannerAuto auto1 = PathPlannerAuto(
        name: 'test',
        sequence:
            SequentialCommandGroup(commands: [WaitCommand(waitTime: 1.0)]),
      );
      PathPlannerAuto auto2 = PathPlannerAuto(
        name: 'test',
        sequence:
            SequentialCommandGroup(commands: [WaitCommand(waitTime: 1.0)]),
      );
      PathPlannerAuto auto3 = PathPlannerAuto(
        name: 'test2',
        sequence: SequentialCommandGroup(commands: []),
      );

      expect(auto2, auto1);
      expect(auto3, isNot(auto1));

      expect(auto3.hashCode, isNot(auto1.hashCode));
    });

    test('toJson/fromJson interoperability', () {
      PathPlannerAuto auto = PathPlannerAuto(
        name: 'test',
        sequence:
            SequentialCommandGroup(commands: [WaitCommand(waitTime: 1.0)]),
      );

      Map<String, dynamic> json = auto.toJson();
      PathPlannerAuto fromJson = PathPlannerAuto.fromJsonV1(json, auto.name);

      expect(fromJson, auto);
    });

    test('duplication', () {
      PathPlannerAuto auto = PathPlannerAuto(
        name: 'test',
        sequence:
            SequentialCommandGroup(commands: [WaitCommand(waitTime: 1.0)]),
      );
      PathPlannerAuto cloned = auto.duplicate(auto.name);

      expect(cloned, auto);

      auto.sequence.commands.clear();

      expect(auto, isNot(cloned));
    });
  });

  test('getAllPathNames', () {
    PathPlannerAuto auto = PathPlannerAuto(
        name: 'test',
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
        ));

    expect(
        listEquals(auto.getAllPathNames(), ['path1', 'path2', 'path3']), true);
  });

  test('updatePathName', () {
    PathPlannerAuto auto = PathPlannerAuto(
        name: 'test',
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
        ));

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
    test('rename', () {
      var fs = MemoryFileSystem();

      Directory autoDir = fs.directory('/autos');
      fs.file(join(autoDir.path, 'test.auto')).createSync(recursive: true);

      PathPlannerAuto auto =
          PathPlannerAuto.defaultAuto(name: 'test', autoDir: autoDir.path);

      auto.rename('renamed', fs: fs);

      expect(auto.name, 'renamed');
      expect(fs.file(join(autoDir.path, 'test.auto')).existsSync(), false);
      expect(fs.file(join(autoDir.path, 'renamed.auto')).existsSync(), true);
    });

    test('delete', () {
      var fs = MemoryFileSystem();

      Directory autoDir = fs.directory('/autos');
      fs.file(join(autoDir.path, 'test.auto')).createSync(recursive: true);

      PathPlannerAuto auto =
          PathPlannerAuto.defaultAuto(name: 'test', autoDir: autoDir.path);

      auto.delete(fs: fs);

      expect(fs.file(join(autoDir.path, 'test.auto')).existsSync(), false);
    });

    test('load autos in dir', () async {
      var fs = MemoryFileSystem();

      Directory autoDir = fs.directory('/autos');
      autoDir.createSync(recursive: true);

      PathPlannerAuto auto1 =
          PathPlannerAuto.defaultAuto(name: 'test1', autoDir: autoDir.path);
      PathPlannerAuto auto2 =
          PathPlannerAuto.defaultAuto(name: 'test2', autoDir: autoDir.path);
      auto2.sequence.commands.add(WaitCommand(waitTime: 0.5));

      fs
          .file(join(autoDir.path, 'test1.auto'))
          .writeAsStringSync(jsonEncode(auto1.toJson()));
      fs
          .file(join(autoDir.path, 'test2.auto'))
          .writeAsStringSync(jsonEncode(auto2.toJson()));

      List<PathPlannerAuto> loaded =
          await PathPlannerAuto.loadAllAutosInDir(autoDir.path, fs: fs);

      expect(loaded.length, 2);

      // Sort autos by name so they should be in the order: auto1, auto2
      loaded.sort((a, b) => a.name.compareTo(b.name));

      expect(loaded[0], auto1);
      expect(loaded[1], auto2);
    });

    test('save', () {
      var fs = MemoryFileSystem();

      Directory autoDir = fs.directory('/autos');
      autoDir.createSync(recursive: true);

      PathPlannerAuto auto =
          PathPlannerAuto.defaultAuto(name: 'test', autoDir: autoDir.path);
      auto.sequence.commands.add(WaitCommand(waitTime: 1.0));

      auto.saveFile(fs: fs);

      File autoFile = fs.file(join(autoDir.path, 'test.auto'));
      expect(autoFile.existsSync(), true);

      String fileContent = autoFile.readAsStringSync();
      Map<String, dynamic> fileJson = jsonDecode(fileContent);
      expect(
          const DeepCollectionEquality().equals(fileJson, auto.toJson()), true);
    });
  });
}
