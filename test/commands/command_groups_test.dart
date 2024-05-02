import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/none_command.dart';
import 'package:pathplanner/commands/wait_command.dart';

void main() {
  group('sequential group', () {
    test('equals/hashCode', () {
      SequentialCommandGroup cmd1 = SequentialCommandGroup(commands: []);
      SequentialCommandGroup cmd2 = SequentialCommandGroup(commands: []);
      SequentialCommandGroup cmd3 =
          SequentialCommandGroup(commands: [const NoneCommand()]);

      expect(cmd2, cmd1);
      expect(cmd3, isNot(cmd1));

      expect(cmd3.hashCode, isNot(cmd1.hashCode));
    });

    test('toJson/fromJson interoperability', () {
      SequentialCommandGroup cmd =
          SequentialCommandGroup(commands: [const NoneCommand()]);

      Map<String, dynamic> json = cmd.toJson();
      Command fromJson = Command.fromJson(json);

      expect(fromJson, cmd);
    });

    test('proper cloning', () {
      SequentialCommandGroup cmd =
          SequentialCommandGroup(commands: [const NoneCommand()]);
      Command cloned = cmd.clone();

      expect(cloned, cmd);

      (cloned as SequentialCommandGroup).commands.add(WaitCommand());
      expect(listEquals(cmd.commands, cloned.commands), false);
    });
  });

  group('parallel group', () {
    test('equals/hashCode', () {
      ParallelCommandGroup cmd1 = ParallelCommandGroup(commands: []);
      ParallelCommandGroup cmd2 = ParallelCommandGroup(commands: []);
      ParallelCommandGroup cmd3 =
          ParallelCommandGroup(commands: [const NoneCommand()]);

      expect(cmd2, cmd1);
      expect(cmd3, isNot(cmd1));

      expect(cmd3.hashCode, isNot(cmd1.hashCode));
    });

    test('toJson/fromJson interoperability', () {
      ParallelCommandGroup cmd =
          ParallelCommandGroup(commands: [const NoneCommand()]);

      Map<String, dynamic> json = cmd.toJson();
      Command fromJson = Command.fromJson(json);

      expect(fromJson, cmd);
    });

    test('proper cloning', () {
      ParallelCommandGroup cmd =
          ParallelCommandGroup(commands: [const NoneCommand()]);
      Command cloned = cmd.clone();

      expect(cloned, cmd);

      (cloned as ParallelCommandGroup).commands.add(WaitCommand());
      expect(listEquals(cmd.commands, cloned.commands), false);
    });
  });

  group('race group', () {
    test('equals/hashCode', () {
      RaceCommandGroup cmd1 = RaceCommandGroup(commands: []);
      RaceCommandGroup cmd2 = RaceCommandGroup(commands: []);
      RaceCommandGroup cmd3 = RaceCommandGroup(commands: [const NoneCommand()]);

      expect(cmd2, cmd1);
      expect(cmd3, isNot(cmd1));

      expect(cmd3.hashCode, isNot(cmd1.hashCode));
    });

    test('toJson/fromJson interoperability', () {
      RaceCommandGroup cmd = RaceCommandGroup(commands: [const NoneCommand()]);

      Map<String, dynamic> json = cmd.toJson();
      Command fromJson = Command.fromJson(json);

      expect(fromJson, cmd);
    });

    test('proper cloning', () {
      RaceCommandGroup cmd = RaceCommandGroup(commands: [const NoneCommand()]);
      Command cloned = cmd.clone();

      expect(cloned, cmd);

      (cloned as RaceCommandGroup).commands.add(WaitCommand());
      expect(listEquals(cmd.commands, cloned.commands), false);
    });
  });

  group('deadline group', () {
    test('equals/hashCode', () {
      DeadlineCommandGroup cmd1 = DeadlineCommandGroup(commands: []);
      DeadlineCommandGroup cmd2 = DeadlineCommandGroup(commands: []);
      DeadlineCommandGroup cmd3 =
          DeadlineCommandGroup(commands: [const NoneCommand()]);

      expect(cmd2, cmd1);
      expect(cmd3, isNot(cmd1));

      expect(cmd3.hashCode, isNot(cmd1.hashCode));
    });

    test('toJson/fromJson interoperability', () {
      DeadlineCommandGroup cmd =
          DeadlineCommandGroup(commands: [const NoneCommand()]);

      Map<String, dynamic> json = cmd.toJson();
      Command fromJson = Command.fromJson(json);

      expect(fromJson, cmd);
    });

    test('proper cloning', () {
      DeadlineCommandGroup cmd =
          DeadlineCommandGroup(commands: [const NoneCommand()]);
      Command cloned = cmd.clone();

      expect(cloned, cmd);

      (cloned as DeadlineCommandGroup).commands.add(WaitCommand());
      expect(listEquals(cmd.commands, cloned.commands), false);
    });
  });
}
